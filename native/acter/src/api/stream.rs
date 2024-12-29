use anyhow::{bail, Context, Result};
use futures::stream::{Stream, StreamExt};
use matrix_sdk::room::{edit::EditedContent, Receipts};
use matrix_sdk_base::{
    ruma::{
        api::client::receipt::create_receipt,
        assign,
        events::{
            receipt::ReceiptThread,
            room::{
                message::{AudioInfo, FileInfo, ForwardThread, VideoInfo},
                ImageInfo,
            },
            MessageLikeEventType,
        },
        EventId, OwnedEventId, OwnedTransactionId,
    },
    RoomState,
};
use matrix_sdk_ui::timeline::{Timeline, TimelineEventItemId};
use std::{ops::Deref, sync::Arc};
use tracing::info;

use crate::{Client, Room, RoomMessage, RUNTIME};

use super::utils::{remap_for_diff, ApiVectorDiff};

pub mod msg_draft;
use msg_draft::MsgContentDraft;
pub use msg_draft::MsgDraft;

pub type RoomMessageDiff = ApiVectorDiff<RoomMessage>;

#[derive(Clone)]
pub struct TimelineStream {
    room: Room,
    timeline: Arc<Timeline>,
}

impl TimelineStream {
    pub fn new(room: Room, timeline: Arc<Timeline>) -> Self {
        TimelineStream { room, timeline }
    }

    pub fn messages_stream(&self) -> impl Stream<Item = RoomMessageDiff> {
        let timeline = self.timeline.clone();
        let user_id = self
            .room
            .deref()
            .client()
            .user_id()
            .expect("User must be logged in")
            .to_owned();

        async_stream::stream! {
            let (timeline_items, mut timeline_stream) = timeline.subscribe().await;
            yield RoomMessageDiff::current_items(timeline_items.clone().into_iter().map(|x| RoomMessage::from((x, user_id.clone()))).collect());

            let mut remap = timeline_stream.map(|diff| remap_for_diff(
                diff,
                |x| RoomMessage::from((x, user_id.clone())),
            ));

            while let Some(d) = remap.next().await {
                yield d
            }
        }
    }

    /// Get the next count messages backwards, and return whether it reached the end
    pub async fn paginate_backwards(&self, mut count: u16) -> Result<bool> {
        let timeline = self.timeline.clone();

        Ok(RUNTIME
            .spawn(async move { timeline.paginate_backwards(count).await })
            .await??)
    }

    pub async fn get_message(&self, event_id: String) -> Result<RoomMessage> {
        let event_id = OwnedEventId::try_from(event_id)?;

        let timeline = self.timeline.clone();
        let user_id = self.room.user_id()?;

        RUNTIME
            .spawn(async move {
                let Some(tl) = timeline.item_by_event_id(&event_id).await else {
                    bail!("Event not found")
                };
                Ok(RoomMessage::new_event_item(user_id, &tl))
            })
            .await?
    }

    fn is_joined(&self) -> bool {
        matches!(self.room.state(), RoomState::Joined)
    }

    pub async fn send_message(&self, draft: Box<MsgDraft>) -> Result<bool> {
        if !self.is_joined() {
            bail!("Unable to send message in a room we are not in");
        }
        let room = self.room.clone();
        let my_id = self.room.user_id()?;
        let timeline = self.timeline.clone();

        RUNTIME
            .spawn(async move {
                let permitted = room
                    .can_user_send_message(&my_id, MessageLikeEventType::RoomMessage)
                    .await?;
                if !permitted {
                    bail!("No permissions to send message in this room");
                }
                let msg = draft.into_room_msg(&room).await?;
                timeline.send(msg.with_relation(None).into()).await;
                Ok(true)
            })
            .await?
    }

    pub async fn edit_message(&self, event_id: String, draft: Box<MsgDraft>) -> Result<bool> {
        if !self.is_joined() {
            bail!("Unable to edit message in a room we are not in");
        }
        let room = self.room.deref().clone();
        let my_id = self.room.user_id()?;
        let timeline = self.timeline.clone();
        let event_id = EventId::parse(event_id)?;
        let client = self.room.client();

        RUNTIME
            .spawn(async move {
                let permitted = room
                    .can_user_send_message(&my_id, MessageLikeEventType::RoomMessage)
                    .await?;
                if !permitted {
                    bail!("No permissions to send message in this room");
                }

                let Some(item) = timeline.item_by_event_id(&event_id).await else {
                    bail!("Unable to find event");
                };

                if !item.is_own() {
                    // !item.is_editable() { // FIXME: matrix-sdk is_editable doesn't allow us to post other things
                    bail!("You can't edit other peoples messages");
                }

                let item = timeline
                    .item_by_event_id(&event_id)
                    .await
                    .context("Not found which item would be edited")?;
                let event_content = draft.into_room_msg(&room).await?;
                let new_content = EditedContent::RoomMessage(event_content);
                timeline.edit(&item.identifier(), new_content).await?;
                Ok(true)
            })
            .await?
    }

    pub async fn reply_message(&self, event_id: String, draft: Box<MsgDraft>) -> Result<bool> {
        if !self.is_joined() {
            bail!("Unable to send reply in a room we are not in");
        }
        let room = self.room.deref().clone();
        let my_id = self.room.user_id()?;
        let timeline = self.timeline.clone();
        let event_id = EventId::parse(event_id)?;
        let client = self.room.client();

        RUNTIME
            .spawn(async move {
                let permitted = room
                    .can_user_send_message(&my_id, MessageLikeEventType::RoomMessage)
                    .await?;
                if !permitted {
                    bail!("No permissions to send message in this room");
                }
                let reply_item = timeline
                    .replied_to_info_from_event_id(&event_id)
                    .await
                    .context("Not found which item would be replied to")?;
                let content = draft.into_room_msg(&room).await?;
                timeline
                    .send_reply(
                        content.with_relation(None).into(),
                        reply_item,
                        ForwardThread::Yes,
                    )
                    .await?;
                Ok(true)
            })
            .await?
    }

    pub async fn send_single_receipt(
        &self,
        receipt_type: String,
        thread: String,
        event_id: String,
    ) -> Result<bool> {
        let timeline = self.timeline.clone();
        let receipt_type = match receipt_type.as_str() {
            "FullyRead" => create_receipt::v3::ReceiptType::FullyRead,
            "Read" => create_receipt::v3::ReceiptType::Read,
            "ReadPrivate" => create_receipt::v3::ReceiptType::ReadPrivate,
            _ => {
                bail!("Wrong receipt type")
            }
        };
        let thread = match thread.as_str() {
            "Main" => ReceiptThread::Main,
            "Unthreaded" => ReceiptThread::Unthreaded,
            _ => {
                bail!("Wrong receipt thread")
            }
        };
        let event_id = EventId::parse(event_id)?;

        RUNTIME
            .spawn(async move {
                timeline
                    .send_single_receipt(receipt_type, thread, event_id)
                    .await?;
                Ok(true)
            })
            .await?
    }

    pub async fn mark_as_read(&self, user_triggered: bool) -> Result<bool> {
        let timeline = self.timeline.clone();
        let receipt = if user_triggered {
            create_receipt::v3::ReceiptType::Read
        } else {
            create_receipt::v3::ReceiptType::FullyRead
        };

        RUNTIME
            .spawn(async move {
                let result = timeline.mark_as_read(receipt).await?;
                Ok(result)
            })
            .await?
    }

    pub async fn send_multiple_receipts(
        &self,
        fully_read: Option<String>,
        public_read_receipt: Option<String>,
        private_read_receipt: Option<String>,
    ) -> Result<bool> {
        let timeline = self.timeline.clone();
        let fully_read = match fully_read {
            Some(x) => match EventId::parse(x) {
                Ok(event_id) => Some(event_id),
                Err(_) => {
                    bail!("full read param should be event id")
                }
            },
            None => None,
        };
        let public_read_receipt = match public_read_receipt {
            Some(x) => match EventId::parse(x) {
                Ok(event_id) => Some(event_id),
                Err(_) => {
                    bail!("public read receipt param should be event id")
                }
            },
            None => None,
        };
        let private_read_receipt = match private_read_receipt {
            Some(x) => match EventId::parse(x) {
                Ok(event_id) => Some(event_id),
                Err(_) => {
                    bail!("private read receipt param should be event id")
                }
            },
            None => None,
        };

        RUNTIME
            .spawn(async move {
                let receipts = Receipts::new()
                    .fully_read_marker(fully_read)
                    .public_read_receipt(public_read_receipt)
                    .private_read_receipt(private_read_receipt);
                timeline.send_multiple_receipts(receipts).await?;
                Ok(true)
            })
            .await?
    }

    pub async fn toggle_reaction(&self, unique_id: String, key: String) -> Result<bool> {
        if !self.is_joined() {
            bail!("Unable to send reaction in a room we are not in");
        }
        let room = self.room.clone();
        let my_id = self.room.user_id()?;
        let timeline = self.timeline.clone();
        let unique_id =
            match OwnedEventId::try_from(unique_id.clone()).map(TimelineEventItemId::EventId) {
                Ok(o) => o,
                Err(e) => TimelineEventItemId::TransactionId(OwnedTransactionId::from(unique_id)),
            };

        RUNTIME
            .spawn(async move {
                let permitted = room
                    .can_user_send_message(&my_id, MessageLikeEventType::Reaction)
                    .await?;
                if !permitted {
                    bail!("No permissions to send reaction in this room");
                }
                timeline.toggle_reaction(&unique_id, &key).await?;
                Ok(true)
            })
            .await?
    }
}

impl Client {
    pub fn text_plain_draft(&self, body: String) -> MsgDraft {
        MsgDraft::new(MsgContentDraft::TextPlain { body })
    }

    pub fn text_markdown_draft(&self, body: String) -> MsgDraft {
        MsgDraft::new(MsgContentDraft::TextMarkdown { body })
    }

    pub fn text_html_draft(&self, html: String, plain: String) -> MsgDraft {
        MsgDraft::new(MsgContentDraft::TextHtml { html, plain })
    }

    pub fn image_draft(&self, source: String, mimetype: String) -> MsgDraft {
        let info = assign!(ImageInfo::new(), {
            mimetype: Some(mimetype),
        });
        MsgDraft::new(MsgContentDraft::Image {
            source,
            info: Some(info),
            filename: None,
        })
    }

    pub fn audio_draft(&self, source: String, mimetype: String) -> MsgDraft {
        let info = assign!(AudioInfo::new(), {
            mimetype: Some(mimetype),
        });
        MsgDraft::new(MsgContentDraft::Audio {
            source,
            info: Some(info),
            filename: None,
        })
    }

    pub fn video_draft(&self, source: String, mimetype: String) -> MsgDraft {
        let info = assign!(VideoInfo::new(), {
            mimetype: Some(mimetype),
        });
        MsgDraft::new(MsgContentDraft::Video {
            source,
            info: Some(info),
            filename: None,
        })
    }

    pub fn file_draft(&self, source: String, mimetype: String) -> MsgDraft {
        let info = assign!(FileInfo::new(), {
            mimetype: Some(mimetype),
        });
        MsgDraft::new(MsgContentDraft::File {
            source,
            info: Some(info),
            filename: None,
        })
    }

    pub fn location_draft(&self, body: String, geo_uri: String) -> MsgDraft {
        MsgDraft::new(MsgContentDraft::Location {
            body,
            geo_uri,
            info: None,
        })
    }
}
