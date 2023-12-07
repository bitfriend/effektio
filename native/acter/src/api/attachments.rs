use acter_core::{
    events::attachments::{AttachmentBuilder, AttachmentContent},
    models::{self, ActerModel, AnyActerModel, Color},
};
use anyhow::{bail, Context, Result};
use core::time::Duration;
use futures::stream::StreamExt;
use matrix_sdk::{
    room::Room,
    ruma::{assign, UInt},
    RoomState,
};
use ruma_common::{MxcUri, OwnedEventId, OwnedUserId};
use ruma_events::room::{
    message::{
        AudioInfo, AudioMessageEventContent, FileInfo, FileMessageEventContent,
        ImageMessageEventContent, LocationMessageEventContent, VideoInfo, VideoMessageEventContent,
    },
    ImageInfo,
};
use std::ops::Deref;
use tokio::sync::broadcast::Receiver;
use tokio_stream::Stream;

use super::{api::FfiBuffer, client::Client, RUNTIME};
use crate::MsgContent;

impl Client {
    pub async fn wait_for_attachment(
        &self,
        key: String,
        timeout: Option<Box<Duration>>,
    ) -> Result<Attachment> {
        let me = self.clone();
        RUNTIME
            .spawn(async move {
                let AnyActerModel::Attachment(attachment) = me.wait_for(key.clone(), timeout).await? else {
                    bail!("{key} is not a attachment");
                };
                let room = me
                    .core
                    .client()
                    .get_room(&attachment.meta.room_id)
                    .context("Room not found")?;
                Ok(Attachment {
                    client: me.clone(),
                    room,
                    inner: attachment,
                })
            })
            .await?
    }
}

#[derive(Clone, Debug)]
pub struct Attachment {
    client: Client,
    room: Room,
    inner: models::Attachment,
}

impl Deref for Attachment {
    type Target = models::Attachment;
    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl Attachment {
    pub fn type_str(&self) -> String {
        self.inner.content().type_str()
    }

    pub fn sender(&self) -> OwnedUserId {
        self.inner.meta.sender.clone()
    }

    pub fn origin_server_ts(&self) -> u64 {
        self.inner.meta.origin_server_ts.get().into()
    }

    pub fn msg_content(&self) -> MsgContent {
        MsgContent::from(&self.inner.content)
    }

    pub async fn source_binary(&self) -> Result<FfiBuffer<u8>> {
        // any variable in self can't be called directly in spawn
        match &self.inner.content {
            AttachmentContent::Image(content) => {
                self.client.source_binary(content.source.clone()).await
            }
            AttachmentContent::Audio(content) => {
                self.client.source_binary(content.source.clone()).await
            }
            AttachmentContent::Video(content) => {
                self.client.source_binary(content.source.clone()).await
            }
            AttachmentContent::File(content) => {
                self.client.source_binary(content.source.clone()).await
            }
            AttachmentContent::Location(content) => {
                let buf = Vec::<u8>::new();
                Ok(FfiBuffer::new(buf))
            }
        }
    }
}

#[derive(Clone, Debug)]
pub struct AttachmentsManager {
    client: Client,
    room: Room,
    inner: models::AttachmentsManager,
}

impl Deref for AttachmentsManager {
    type Target = models::AttachmentsManager;
    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

pub struct AttachmentDraft {
    client: Client,
    room: Room,
    inner: AttachmentBuilder,
}

impl AttachmentDraft {
    pub async fn send(&self) -> Result<OwnedEventId> {
        let room = self.room.clone();
        let inner = self.inner.build()?;
        RUNTIME
            .spawn(async move {
                let resp = room.send(inner).await?;
                Ok(resp.event_id)
            })
            .await?
    }
}

impl AttachmentsManager {
    pub(crate) fn new(
        client: Client,
        room: Room,
        inner: models::AttachmentsManager,
    ) -> AttachmentsManager {
        AttachmentsManager {
            client,
            room,
            inner,
        }
    }

    pub fn stats(&self) -> models::AttachmentsStats {
        self.inner.stats().clone()
    }

    pub fn has_attachments(&self) -> bool {
        *self.stats().has_attachments()
    }

    pub fn attachments_count(&self) -> u32 {
        *self.stats().total_attachments_count()
    }

    pub async fn attachments(&self) -> Result<Vec<Attachment>> {
        let manager = self.inner.clone();
        let client = self.client.clone();
        let room = self.room.clone();

        RUNTIME
            .spawn(async move {
                let res = manager
                    .attachments()
                    .await?
                    .into_iter()
                    .map(|inner| Attachment {
                        client: client.clone(),
                        room: room.clone(),
                        inner,
                    })
                    .collect();
                Ok(res)
            })
            .await?
    }

    fn is_joined(&self) -> bool {
        matches!(self.room.state(), RoomState::Joined)
    }

    pub fn attachment_draft(&self) -> Result<AttachmentDraft> {
        if !self.is_joined() {
            bail!("Can only attachment in joined rooms");
        }
        Ok(AttachmentDraft {
            client: self.client.clone(),
            room: self.room.clone(),
            inner: self.inner.draft_builder(),
        })
    }

    #[allow(clippy::too_many_arguments)]
    pub fn image_attachment_draft(
        &self,
        body: String,
        url: String,
        mimetype: Option<String>,
        size: Option<u64>,
        width: Option<u64>,
        height: Option<u64>,
        blurhash: Option<String>,
    ) -> Result<AttachmentDraft> {
        if !self.is_joined() {
            bail!("Can only attachment in joined rooms");
        }
        let info = assign!(ImageInfo::new(), {
            height: height.and_then(UInt::new),
            width: width.and_then(UInt::new),
            mimetype,
            size: size.and_then(UInt::new),
            blurhash,
        });
        let url = Box::<MxcUri>::from(url.as_str());
        let mut builder = self.inner.draft_builder();

        let mut image_content = ImageMessageEventContent::plain(body, url.into());
        image_content.info = Some(Box::new(info));
        builder.content(AttachmentContent::Image(image_content));
        Ok(AttachmentDraft {
            client: self.client.clone(),
            room: self.room.clone(),
            inner: builder,
        })
    }

    pub fn audio_attachment_draft(
        &self,
        body: String,
        url: String,
        mimetype: Option<String>,
        size: Option<u64>,
        secs: Option<u64>,
    ) -> Result<AttachmentDraft> {
        if !self.is_joined() {
            bail!("Can only attachment in joined rooms");
        }
        let info = assign!(AudioInfo::new(), {
            duration: secs.map(|x| Duration::new(x, 0)),
            mimetype,
            size: size.and_then(UInt::new),
        });
        let url = Box::<MxcUri>::from(url.as_str());
        let mut builder = self.inner.draft_builder();

        let mut audio_content = AudioMessageEventContent::plain(body, url.into());
        audio_content.info = Some(Box::new(info));
        builder.content(AttachmentContent::Audio(audio_content));
        Ok(AttachmentDraft {
            client: self.client.clone(),
            room: self.room.clone(),
            inner: builder,
        })
    }

    #[allow(clippy::too_many_arguments)]
    pub fn video_attachment_draft(
        &self,
        body: String,
        url: String,
        mimetype: Option<String>,
        size: Option<u64>,
        secs: Option<u64>,
        width: Option<u64>,
        height: Option<u64>,
        blurhash: Option<String>,
    ) -> Result<AttachmentDraft> {
        if !self.is_joined() {
            bail!("Can only attachment in joined rooms");
        }
        let info = assign!(VideoInfo::new(), {
            duration: secs.map(|x| Duration::new(x, 0)),
            height: height.and_then(UInt::new),
            width: width.and_then(UInt::new),
            mimetype,
            size: size.and_then(UInt::new),
            blurhash,
        });
        let url = Box::<MxcUri>::from(url.as_str());
        let mut builder = self.inner.draft_builder();

        let mut video_content = VideoMessageEventContent::plain(body, url.into());
        video_content.info = Some(Box::new(info));
        builder.content(AttachmentContent::Video(video_content));
        Ok(AttachmentDraft {
            client: self.client.clone(),
            room: self.room.clone(),
            inner: builder,
        })
    }

    pub fn file_attachment_draft(
        &self,
        body: String,
        url: String,
        mimetype: Option<String>,
        size: Option<u64>,
    ) -> Result<AttachmentDraft> {
        if !self.is_joined() {
            bail!("Can only attachment in joined rooms");
        }
        let mut builder = self.inner.draft_builder();
        let size = size.and_then(UInt::new);
        let info = assign!(FileInfo::new(), { mimetype, size });
        let mut file_content = FileMessageEventContent::plain(body, url.into());
        file_content.info = Some(Box::new(info));
        builder.content(AttachmentContent::File(file_content));
        Ok(AttachmentDraft {
            client: self.client.clone(),
            room: self.room.clone(),
            inner: builder,
        })
    }

    pub fn subscribe_stream(&self) -> impl Stream<Item = bool> {
        self.client.subscribe_stream(self.inner.update_key())
    }

    pub fn subscribe(&self) -> Receiver<()> {
        self.client.subscribe(self.inner.update_key())
    }
}
