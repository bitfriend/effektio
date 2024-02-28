use derive_builder::Builder;
use ruma_common::{
    event_id, room_id, user_id, EventId, MilliSecondsSinceUnixEpoch, OwnedEventId, UserId,
};
use serde::{Deserialize, Serialize};

use super::{default_model_execute, ActerModel, AnyActerModel, Capability, EventMeta};
use crate::{store::Store, Result};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize, Builder)]
pub struct TestModel {
    event_id: OwnedEventId,

    #[builder(default)]
    indizes: Vec<String>,

    #[builder(default)]
    belongs_to: Vec<String>,

    #[builder(default)]
    transition: bool,
}

impl TestModelBuilder {
    pub fn simple(&mut self) -> &mut Self {
        self.event_id(EventId::parse("$asdefttg").unwrap())
    }

    pub fn fake_meta() -> EventMeta {
        EventMeta {
            event_id: event_id!("$ASDas29ak").to_owned(),
            sender: user_id!("@test:example.org").to_owned(),
            origin_server_ts: MilliSecondsSinceUnixEpoch(123567890u32.into()),
            room_id: room_id!("!5678ijhgasdf093:Asdfa").to_owned(),
        }
    }
}

impl ActerModel for TestModel {
    fn event_id(&self) -> &EventId {
        &self.event_id
    }

    fn capabilities(&self) -> &[Capability] {
        &[Capability::Commentable, Capability::Reactable]
    }

    fn indizes(&self, _user_id: &UserId) -> Vec<String> {
        self.indizes.clone()
    }

    fn belongs_to(&self) -> Option<Vec<String>> {
        Some(self.belongs_to.clone())
    }

    fn transition(&mut self, _model: &AnyActerModel) -> Result<bool> {
        Ok(true)
    }

    async fn execute(self, store: &Store) -> Result<Vec<String>> {
        default_model_execute(store, self.into()).await
    }
}
