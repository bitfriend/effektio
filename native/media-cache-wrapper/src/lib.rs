use async_trait::async_trait;
use base64ct::{Base64UrlUnpadded, Encoding};
use core::fmt::Debug;
use matrix_sdk_base::ruma::{
    self,
    events::{
        presence::PresenceEvent,
        receipt::{Receipt, ReceiptThread, ReceiptType},
        AnyGlobalAccountDataEvent, AnyRoomAccountDataEvent, GlobalAccountDataEventType,
        RoomAccountDataEventType, StateEventType,
    },
    serde::Raw,
    EventId, OwnedEventId, OwnedUserId, RoomId, UserId,
};
use matrix_sdk_base::{
    deserialized_responses::RawAnySyncOrStrippedState,
    media::{MediaRequest, UniqueKey},
    store::StoreEncryptionError,
    MinimalRoomMemberEvent, RoomInfo, RoomMemberships, StateChanges, StateStore, StateStoreDataKey,
    StateStoreDataValue, StoreError,
};
use matrix_sdk_store_encryption::StoreCipher;
use serde_json;

use std::{
    collections::{BTreeMap, BTreeSet},
    fs,
    path::PathBuf,
};

use tracing::instrument;
#[async_trait]
trait MediaStore: Debug + Sync + Send {
    type Error: Debug + Into<StoreError> + From<serde_json::Error>;

    async fn add_media_content(
        &self,
        request: &MediaRequest,
        content: Vec<u8>,
    ) -> Result<(), Self::Error>;

    async fn get_media_content(
        &self,
        request: &MediaRequest,
    ) -> Result<Option<Vec<u8>>, Self::Error>;

    async fn remove_media_content(&self, request: &MediaRequest) -> Result<(), Self::Error>;

    async fn remove_media_content_for_uri(&self, uri: &ruma::MxcUri) -> Result<(), Self::Error>;
}

pub struct FileCacheMediaStore {
    cache_dir: PathBuf,
    store_cipher: StoreCipher,
}

impl Debug for FileCacheMediaStore {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("FileCacheMediaStore")
            .field("cache_dir", &self.cache_dir)
            .finish()
    }
}

impl FileCacheMediaStore {
    pub fn with_store_cipher(cache_dir: PathBuf, store_cipher: StoreCipher) -> FileCacheMediaStore {
        FileCacheMediaStore {
            cache_dir: cache_dir,
            store_cipher,
        }
    }

    fn encode_value(&self, value: Vec<u8>) -> Result<Vec<u8>, StoreError> {
        let encoded = self
            .store_cipher
            .encrypt_value_data(value)
            .map_err(StoreError::backend)?;
        rmp_serde::to_vec_named(&encoded).map_err(StoreError::backend)
    }

    fn decode_value<'a>(&self, value: &'a [u8]) -> Result<Vec<u8>, StoreError> {
        let encrypted = rmp_serde::from_slice(value).map_err(StoreError::backend)?;
        self.store_cipher
            .decrypt_value_data(encrypted)
            .map_err(StoreError::backend)
    }

    fn encode_key(&self, key: impl AsRef<[u8]>) -> String {
        Base64UrlUnpadded::encode_string(&self.store_cipher.hash_key("ext_media", key.as_ref()))
    }
}

#[async_trait]
impl MediaStore for FileCacheMediaStore {
    type Error = StoreError;

    #[instrument(skip_all)]
    async fn add_media_content(
        &self,
        request: &MediaRequest,
        content: Vec<u8>,
    ) -> Result<(), Self::Error> {
        let base_filename = self.encode_key(request.source.unique_key());
        let data = self
            .encode_value(content)
            .map_err(|e| StoreError::Backend(Box::new(e)))?;
        fs::write(self.cache_dir.join(base_filename), data)
            .map_err(|e| StoreError::Backend(Box::new(e)))?;
        Ok(())
    }

    #[instrument(skip_all)]
    async fn get_media_content(
        &self,
        request: &MediaRequest,
    ) -> Result<Option<Vec<u8>>, Self::Error> {
        let base_filename = self.encode_key(request.source.unique_key());
        fs::read(self.cache_dir.join(base_filename))
            .ok()
            .map(|data| self.decode_value(&data))
            .transpose()
    }

    #[instrument(skip_all)]
    async fn remove_media_content(&self, request: &MediaRequest) -> Result<(), Self::Error> {
        let base_filename = self.encode_key(request.source.unique_key());
        fs::remove_file(self.cache_dir.join(base_filename))
            .map_err(|e| StoreError::Backend(Box::new(e)))?;
        Ok(())
    }

    #[instrument(skip_all)]
    async fn remove_media_content_for_uri(&self, uri: &ruma::MxcUri) -> Result<(), Self::Error> {
        let base_filename = self.encode_key(uri);
        fs::remove_file(self.cache_dir.join(base_filename))
            .map_err(|e| StoreError::Backend(Box::new(e)))?;
        Ok(())
    }
}

#[derive(Debug)]
pub enum StoreCacheWrapperError {
    StoreError(StoreError),
    EncryptionError(StoreEncryptionError),
}

impl From<StoreError> for StoreCacheWrapperError {
    fn from(value: StoreError) -> Self {
        StoreCacheWrapperError::StoreError(value)
    }
}

impl From<StoreEncryptionError> for StoreCacheWrapperError {
    fn from(value: StoreEncryptionError) -> Self {
        StoreCacheWrapperError::EncryptionError(value)
    }
}

impl From<serde_json::error::Error> for StoreCacheWrapperError {
    fn from(value: serde_json::error::Error) -> Self {
        StoreCacheWrapperError::StoreError(StoreError::Json(value))
    }
}

impl Into<StoreError> for StoreCacheWrapperError {
    fn into(self) -> StoreError {
        match self {
            StoreCacheWrapperError::StoreError(e) => e,
            StoreCacheWrapperError::EncryptionError(e) => StoreError::backend(Box::new(e)),
        }
    }
}

impl core::fmt::Display for StoreCacheWrapperError {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            StoreCacheWrapperError::StoreError(e) => {
                write!(f, "StoreCacheWrapperError::StoreError: {:?}", e)
            }
            StoreCacheWrapperError::EncryptionError(e) => {
                write!(f, "StoreCacheWrapperError::EncryptionError: {:?}", e)
            }
        }
    }
}

impl std::error::Error for StoreCacheWrapperError {}

pub async fn wrap_with_file_cache<T>(
    state_store: T,
    cache_path: PathBuf,
    passphrase: &str,
) -> Result<MediaStoreWrapper<T, FileCacheMediaStore>, StoreCacheWrapperError>
where
    T: StateStore + Sync + Send,
{
    let cipher = if let Some(enc_key) = state_store
        .get_custom_value(b"ext_media_key")
        .await
        .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?
    {
        let cipher = StoreCipher::import(passphrase, &enc_key)
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?;
        cipher
    } else {
        let cipher = StoreCipher::new()?;
        let key = cipher
            .export(passphrase)
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?;
        state_store
            .set_custom_value(b"ext_media_key", key)
            .await
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?;
        cipher
    };

    Ok(MediaStoreWrapper::new(
        state_store,
        FileCacheMediaStore::with_store_cipher(cache_path, cipher),
    ))
}

#[derive(Debug)]
pub struct MediaStoreWrapper<T, M>
where
    T: Debug,
    M: Debug,
{
    inner: T,
    media: M,
}

impl<T, M> MediaStoreWrapper<T, M>
where
    T: Debug,
    M: Debug,
{
    pub fn new(inner: T, media: M) -> MediaStoreWrapper<T, M> {
        MediaStoreWrapper { inner, media }
    }
}

#[async_trait]
impl<T, M> StateStore for MediaStoreWrapper<T, M>
where
    T: StateStore + Sync + Send,
    M: MediaStore + Sync + Send,
{
    type Error = StoreCacheWrapperError;

    async fn get_kv_data(
        &self,
        key: StateStoreDataKey<'_>,
    ) -> Result<Option<StateStoreDataValue>, Self::Error> {
        Ok(self
            .inner
            .get_kv_data(key)
            .await
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?)
    }

    async fn set_kv_data(
        &self,
        key: StateStoreDataKey<'_>,
        value: StateStoreDataValue,
    ) -> Result<(), Self::Error> {
        Ok(self
            .inner
            .set_kv_data(key, value)
            .await
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?)
    }

    async fn remove_kv_data(&self, key: StateStoreDataKey<'_>) -> Result<(), Self::Error> {
        Ok(self
            .inner
            .remove_kv_data(key)
            .await
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?)
    }

    async fn save_changes(&self, changes: &StateChanges) -> Result<(), Self::Error> {
        Ok(self
            .inner
            .save_changes(changes)
            .await
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?)
    }

    async fn get_presence_event(
        &self,
        user_id: &UserId,
    ) -> Result<Option<Raw<PresenceEvent>>, Self::Error> {
        self.get_presence_event(user_id).await
    }

    async fn get_presence_events(
        &self,
        user_ids: &[OwnedUserId],
    ) -> Result<Vec<Raw<PresenceEvent>>, Self::Error> {
        self.get_presence_events(user_ids).await
    }

    async fn get_state_event(
        &self,
        room_id: &RoomId,
        event_type: StateEventType,
        state_key: &str,
    ) -> Result<Option<RawAnySyncOrStrippedState>, Self::Error> {
        self.get_state_event(room_id, event_type, state_key).await
    }

    async fn get_state_events(
        &self,
        room_id: &RoomId,
        event_type: StateEventType,
    ) -> Result<Vec<RawAnySyncOrStrippedState>, Self::Error> {
        self.get_state_events(room_id, event_type).await
    }

    async fn get_state_events_for_keys(
        &self,
        room_id: &RoomId,
        event_type: StateEventType,
        state_keys: &[&str],
    ) -> Result<Vec<RawAnySyncOrStrippedState>, Self::Error> {
        self.get_state_events_for_keys(room_id, event_type, state_keys)
            .await
    }

    async fn get_profile(
        &self,
        room_id: &RoomId,
        user_id: &UserId,
    ) -> Result<Option<MinimalRoomMemberEvent>, Self::Error> {
        self.get_profile(room_id, user_id).await
    }

    async fn get_profiles<'a>(
        &self,
        room_id: &RoomId,
        user_ids: &'a [OwnedUserId],
    ) -> Result<BTreeMap<&'a UserId, MinimalRoomMemberEvent>, Self::Error> {
        self.get_profiles(room_id, user_ids).await
    }

    async fn get_user_ids(
        &self,
        room_id: &RoomId,
        membership: RoomMemberships,
    ) -> Result<Vec<OwnedUserId>, Self::Error> {
        self.get_user_ids(room_id, membership).await
    }

    async fn get_invited_user_ids(
        &self,
        room_id: &RoomId,
    ) -> Result<Vec<OwnedUserId>, Self::Error> {
        self.get_invited_user_ids(room_id).await
    }

    async fn get_joined_user_ids(&self, room_id: &RoomId) -> Result<Vec<OwnedUserId>, Self::Error> {
        self.get_joined_user_ids(room_id).await
    }

    async fn get_room_infos(&self) -> Result<Vec<RoomInfo>, Self::Error> {
        self.get_room_infos().await
    }

    async fn get_stripped_room_infos(&self) -> Result<Vec<RoomInfo>, Self::Error> {
        self.get_stripped_room_infos().await
    }

    async fn get_users_with_display_name(
        &self,
        room_id: &RoomId,
        display_name: &str,
    ) -> Result<BTreeSet<OwnedUserId>, Self::Error> {
        self.get_users_with_display_name(room_id, display_name)
            .await
    }

    async fn get_users_with_display_names<'a>(
        &self,
        room_id: &RoomId,
        display_names: &'a [String],
    ) -> Result<BTreeMap<&'a str, BTreeSet<OwnedUserId>>, Self::Error> {
        self.get_users_with_display_names(room_id, display_names)
            .await
    }

    async fn get_account_data_event(
        &self,
        event_type: GlobalAccountDataEventType,
    ) -> Result<Option<Raw<AnyGlobalAccountDataEvent>>, Self::Error> {
        self.get_account_data_event(event_type).await
    }

    async fn get_room_account_data_event(
        &self,
        room_id: &RoomId,
        event_type: RoomAccountDataEventType,
    ) -> Result<Option<Raw<AnyRoomAccountDataEvent>>, Self::Error> {
        self.get_room_account_data_event(room_id, event_type).await
    }

    async fn get_user_room_receipt_event(
        &self,
        room_id: &RoomId,
        receipt_type: ReceiptType,
        thread: ReceiptThread,
        user_id: &UserId,
    ) -> Result<Option<(OwnedEventId, Receipt)>, Self::Error> {
        self.get_user_room_receipt_event(room_id, receipt_type, thread, user_id)
            .await
    }

    async fn get_event_room_receipt_events(
        &self,
        room_id: &RoomId,
        receipt_type: ReceiptType,
        thread: ReceiptThread,
        event_id: &EventId,
    ) -> Result<Vec<(OwnedUserId, Receipt)>, Self::Error> {
        self.get_event_room_receipt_events(room_id, receipt_type, thread, event_id)
            .await
    }

    async fn get_custom_value(&self, key: &[u8]) -> Result<Option<Vec<u8>>, Self::Error> {
        self.get_custom_value(key).await
    }

    async fn set_custom_value(
        &self,
        key: &[u8],
        value: Vec<u8>,
    ) -> Result<Option<Vec<u8>>, Self::Error> {
        self.set_custom_value(key, value).await
    }

    async fn remove_custom_value(&self, key: &[u8]) -> Result<Option<Vec<u8>>, Self::Error> {
        self.remove_custom_value(key).await
    }

    async fn remove_room(&self, room_id: &RoomId) -> Result<(), Self::Error> {
        Ok(self
            .inner
            .remove_room(room_id)
            .await
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?)
    }

    // All the media stuff!

    async fn add_media_content(
        &self,
        request: &MediaRequest,
        content: Vec<u8>,
    ) -> Result<(), Self::Error> {
        Ok(self
            .media
            .add_media_content(request, content)
            .await
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?)
    }

    async fn get_media_content(
        &self,
        request: &MediaRequest,
    ) -> Result<Option<Vec<u8>>, Self::Error> {
        Ok(self
            .media
            .get_media_content(request)
            .await
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?)
    }

    async fn remove_media_content(&self, request: &MediaRequest) -> Result<(), Self::Error> {
        Ok(self
            .media
            .remove_media_content(request)
            .await
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?)
    }

    async fn remove_media_content_for_uri(&self, uri: &ruma::MxcUri) -> Result<(), Self::Error> {
        Ok(self
            .media
            .remove_media_content_for_uri(uri)
            .await
            .map_err(|e| StoreCacheWrapperError::StoreError(e.into()))?)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use anyhow::Result;
    use matrix_sdk_base::ruma::{events::room::MediaSource, OwnedMxcUri};
    use matrix_sdk_sqlite::SqliteStateStore;
    use matrix_sdk_test::async_test;
    use tempfile;

    fn fake_mr(id: &str) -> MediaRequest {
        MediaRequest {
            source: MediaSource::Plain(OwnedMxcUri::from(id)),
            format: matrix_sdk_base::media::MediaFormat::File,
        }
    }

    #[async_test]
    async fn it_works() -> Result<()> {
        let cache_dir = tempfile::tempdir()?;
        let cipher = StoreCipher::new()?;
        let fmc = FileCacheMediaStore::with_store_cipher(cache_dir.into_path(), cipher);
        let some_content = "this is some content";
        fmc.add_media_content(&fake_mr("my_id"), some_content.into())
            .await?;
        assert_eq!(
            fmc.get_media_content(&fake_mr("my_id")).await?,
            Some(some_content.into())
        );

        Ok(())
    }

    #[async_test]
    async fn it_works_after_restart() -> Result<()> {
        let cache_dir = tempfile::tempdir()?;
        let passphrase = "this is a secret passphrase";
        let some_content = "this is some content";
        let my_item_id = "my_id";
        let enc_key = {
            // first media cache
            let cipher = StoreCipher::new()?;
            let fmc =
                FileCacheMediaStore::with_store_cipher(cache_dir.path().to_path_buf(), cipher);
            fmc.add_media_content(&fake_mr(my_item_id), some_content.into())
                .await?;
            assert_eq!(
                fmc.get_media_content(&fake_mr(my_item_id)).await?,
                Some(some_content.into())
            );
            fmc.export(passphrase)?
        };

        // second media cache
        let cipher = StoreCipher::import(passphrase, &enc_key)?;
        let fmc = FileCacheMediaStore::with_store_cipher(cache_dir.path().to_path_buf(), cipher);
        assert_eq!(
            fmc.get_media_content(&fake_mr(my_item_id)).await?,
            Some(some_content.into())
        );

        Ok(())
    }

    #[async_test]
    async fn test_with_sqlite_store() -> Result<()> {
        let db_path = tempfile::tempdir()?;
        let cache_dir = tempfile::tempdir()?;
        let passphrase = uuid::Uuid::new_v4().to_string();
        let some_content = "this is some content";
        let my_item_id = "my_id";
        {
            // as a block means we are closing things up
            let db = SqliteStateStore::open(db_path.path(), Some(&passphrase)).await?;
            let outer =
                wrap_with_file_cache(db, cache_dir.path().to_path_buf(), &passphrase).await?;
            // first media cache
            outer
                .add_media_content(&fake_mr(my_item_id), some_content.into())
                .await?;
            assert_eq!(
                outer.get_media_content(&fake_mr(my_item_id)).await?,
                Some(some_content.into())
            );
        };

        // second media cache
        let db = SqliteStateStore::open(db_path, Some(&passphrase)).await?;
        let outer = wrap_with_file_cache(db, cache_dir.path().to_path_buf(), &passphrase).await?;
        // first media cache
        outer
            .add_media_content(&fake_mr(my_item_id), some_content.into())
            .await?;
        assert_eq!(
            outer.get_media_content(&fake_mr(my_item_id)).await?,
            Some(some_content.into())
        );

        Ok(())
    }
}
