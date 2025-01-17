use derive_getters::Getters;
use matrix_sdk_base::ruma::{
    events::OriginalMessageLikeEvent, EventId, OwnedEventId, OwnedUserId, RoomId, UserId,
};
use serde::{Deserialize, Serialize};
use std::ops::Deref;
use tracing::{error, info, trace};

use super::{ActerModel, Capability, EventMeta, RedactedActerModel};
use crate::{
    events::read_receipt::ReadReceiptEventContent,
    store::Store,
    util::{is_false, is_zero},
    Result,
};

static READ_RECEIPTS: &str = "read_receipts";

#[derive(Clone, Debug, Default, Deserialize, Serialize, Getters)]
pub struct ReadReceiptStats {
    #[serde(default, skip_serializing_if = "is_false")]
    pub user_has_read: bool,
    #[serde(default, skip_serializing_if = "is_zero")]
    pub total_views: u32,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub users_viewed: Vec<OwnedUserId>,
}

#[derive(Clone, Debug)]
pub struct ReadReceiptsManager {
    pub stats: ReadReceiptStats,
    event_id: OwnedEventId,
    store: Store,
}

impl ReadReceiptsManager {
    fn stats_field_for<T: AsRef<str>>(parent: &T) -> String {
        let r = parent.as_ref();
        format!("{r}::{READ_RECEIPTS}")
    }

    pub async fn from_store_and_event_id(store: &Store, event_id: &EventId) -> ReadReceiptsManager {
        let store = store.clone();
        let stats = match store.get_raw(&Self::stats_field_for(&event_id)).await {
            Ok(e) => e,
            Err(error) => {
                info!(
                    ?error,
                    ?event_id,
                    "failed to read read-tracking stats. starting with default"
                );
                Default::default()
            }
        };

        ReadReceiptsManager {
            store,
            stats,
            event_id: event_id.to_owned(),
        }
    }

    pub fn event_id(&self) -> OwnedEventId {
        self.event_id.clone()
    }

    pub fn construct_read_event(&self) -> ReadReceiptEventContent {
        ReadReceiptEventContent::new(self.event_id.clone())
    }

    pub async fn add_receipt(&mut self, user_id: &OwnedUserId) -> Result<Option<String>> {
        if self.stats.users_viewed.contains(user_id) {
            // no update to perform
            return Ok(None);
        }

        if self.store.user_id() == user_id {
            self.stats.user_has_read = true;
        }
        self.stats.total_views += 1;
        self.stats.users_viewed.push(user_id.clone());
        Ok(Some(self.save().await?))
    }

    pub fn stats(&self) -> ReadReceiptStats {
        self.stats.clone()
    }

    pub fn update_key(&self) -> String {
        Self::stats_field_for(&self.event_id)
    }

    async fn save(&self) -> Result<String> {
        trace!(?self.stats, ?self.event_id, "Updated entry");
        let update_key = self.update_key();
        self.store.set_raw(&update_key, &self.stats).await?;
        Ok(update_key)
    }
}

impl Deref for ReadReceiptsManager {
    type Target = ReadReceiptStats;
    fn deref(&self) -> &Self::Target {
        &self.stats
    }
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct ReadReceipt {
    pub(crate) inner: ReadReceiptEventContent,
    pub meta: EventMeta,
}

impl Deref for ReadReceipt {
    type Target = ReadReceiptEventContent;
    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl ReadReceipt {
    pub fn index_for<T: AsRef<str>>(parent: &T) -> String {
        let r = parent.as_ref();
        format!("{r}::{READ_RECEIPTS}")
    }

    pub fn event_id(&self) -> &OwnedEventId {
        &self.meta.event_id
    }

    async fn apply(&self, store: &Store) -> Result<Vec<String>> {
        let belongs_to = self.inner.on.event_id.to_string();
        trace!(event_id=?self.event_id(), ?belongs_to, "applying read receipt");

        let model = store.get(&belongs_to).await?;
        if !model.capabilities().contains(&Capability::ReadTracking) {
            error!(?model, reaction = ?self, "doesn’t support read tracking. ignoring");
            return Ok(vec![]);
        }

        let mut manager =
            ReadReceiptsManager::from_store_and_event_id(store, model.event_id()).await;
        trace!(event_id=?self.event_id(), "adding read_tracking entry");
        let mut updates = store.save(self.clone().into()).await?;
        trace!(event_id=?self.event_id(), "saved read tracking entry");
        if let Some(manager_update) = manager.add_receipt(&self.meta.sender).await? {
            updates.push(manager_update);
            trace!(event_id=?self.event_id(), "saved read tracking manager entry");
        }
        Ok(updates)
    }
}

impl ActerModel for ReadReceipt {
    fn indizes(&self, _user_id: &UserId) -> Vec<String> {
        vec![ReadReceipt::index_for(&self.inner.on.event_id)]
    }

    fn event_id(&self) -> &EventId {
        &self.meta.event_id
    }
    fn room_id(&self) -> &RoomId {
        &self.meta.room_id
    }

    async fn execute(self, store: &Store) -> Result<Vec<String>> {
        self.apply(store).await
    }

    fn belongs_to(&self) -> Option<Vec<String>> {
        // Do not trigger the parent to update, we have a manager
        None
    }

    // custom redaction code
    async fn redact(
        &self,
        _store: &Store,
        _redaction_model: RedactedActerModel,
    ) -> crate::Result<Vec<String>> {
        // we don't have redaction support
        Ok(vec![])
    }
}

impl From<OriginalMessageLikeEvent<ReadReceiptEventContent>> for ReadReceipt {
    fn from(outer: OriginalMessageLikeEvent<ReadReceiptEventContent>) -> Self {
        let OriginalMessageLikeEvent {
            content,
            room_id,
            event_id,
            sender,
            origin_server_ts,
            ..
        } = outer;
        ReadReceipt {
            inner: content,
            meta: EventMeta {
                room_id,
                event_id,
                sender,
                origin_server_ts,
                redacted: None,
            },
        }
    }
}
