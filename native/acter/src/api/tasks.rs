use acter_core::{
    events::{
        tasks::{self, Priority, TaskBuilder, TaskListBuilder},
        TextMessageEventContent, UtcDateTime,
    },
    models::{self, ActerModel, AnyActerModel, Color, TaskStats},
    ruma::{OwnedEventId, OwnedRoomId, OwnedUserId},
    statics::KEYS,
    util::DateTime,
};
use anyhow::{bail, Context, Result};
use async_broadcast::Receiver;
use core::time::Duration;
use matrix_sdk::{room::Joined, room::Room};
use std::collections::{hash_map::Entry, HashMap};

use super::{client::Client, spaces::Space, RUNTIME};

impl Client {
    pub async fn wait_for_task_list(
        &self,
        key: String,
        timeout: Option<Box<Duration>>,
    ) -> Result<TaskList> {
        let AnyActerModel::TaskList(inner) = self.wait_for(key.clone(), timeout).await? else {
            bail!("{key} is not a task");
        };
        let room = self
            .core
            .client()
            .get_room(inner.room_id())
            .context("Room not found")?;
        Ok(TaskList {
            client: self.clone(),
            room,
            inner,
        })
    }

    pub async fn wait_for_task(&self, key: String, timeout: Option<Box<Duration>>) -> Result<Task> {
        let AnyActerModel::Task(inner) = self.wait_for(key.clone(), timeout).await? else {
            bail!("{key} is not a task");
        };
        let room = self
            .core
            .client()
            .get_room(inner.room_id())
            .context("Room not found")?;
        Ok(Task {
            client: self.clone(),
            room,
            inner,
        })
    }

    pub async fn task_lists(&self) -> Result<Vec<TaskList>> {
        let mut task_lists = Vec::new();
        let mut rooms_map: HashMap<OwnedRoomId, Room> = HashMap::new();
        let client = self.clone();
        for mdl in self.store().get_list(KEYS::TASKS).await? {
            #[allow(irrefutable_let_patterns)]
            if let AnyActerModel::TaskList(inner) = mdl {
                let room_id = inner.room_id().to_owned();
                let room = match rooms_map.entry(room_id) {
                    Entry::Occupied(t) => t.get().clone(),
                    Entry::Vacant(e) => {
                        if let Some(room) = client.get_room(e.key()) {
                            e.insert(room.clone());
                            room
                        } else {
                            /// User not part of the room anymore, ignore
                            continue;
                        }
                    }
                };
                task_lists.push(TaskList {
                    client: client.clone(),
                    room,
                    inner,
                })
            } else {
                tracing::warn!("Non task list model found in `tasks` index: {:?}", mdl);
            }
        }
        Ok(task_lists)
    }

    pub async fn task_list(&self, key: &str) -> Result<TaskList> {
        let client = self.clone();
        let mdl = self.store().get(key).await?;

        let AnyActerModel::TaskList(inner) = mdl else  {
            bail!("Not a Tasklist model: {key}")
        };
        let Some(room) = client.get_room(inner.room_id()) else {
            bail!("Room not found for task_list item");
        };

        Ok(TaskList {
            client: client.clone(),
            room,
            inner,
        })
    }
}

impl Space {
    pub async fn task_lists(&self) -> Result<Vec<TaskList>> {
        let mut task_lists = Vec::new();
        let room_id = self.room_id();
        for mdl in self
            .client
            .store()
            .get_list(&format!("{room_id}::{}", KEYS::TASKS))
            .await?
        {
            #[allow(irrefutable_let_patterns)]
            if let AnyActerModel::TaskList(inner) = mdl {
                task_lists.push(TaskList {
                    client: self.client.clone(),
                    room: self.room.clone(),
                    inner,
                })
            } else {
                tracing::warn!("Non task list model found in `tasks` index: {:?}", mdl);
            }
        }
        Ok(task_lists)
    }

    pub async fn task_list(&self, key: &str) -> Result<TaskList> {
        let mdl = self.client.store().get(key).await?;

        let AnyActerModel::TaskList(inner) = mdl else  {
            bail!("Not a Tasklist model: {key}")
        };
        assert!(
            self.room_id() == inner.room_id(),
            "This task doesn't belong to this room"
        );

        Ok(TaskList {
            client: self.client.clone(),
            room: self.room.clone(),
            inner,
        })
    }
}

#[derive(Clone, Debug)]
pub struct TaskListDraft {
    client: Client,
    room: Joined,
    content: TaskListBuilder,
}

impl TaskListDraft {
    pub fn name(&mut self, name: String) -> &mut Self {
        self.content.name(name);
        self
    }

    pub fn description_text(&mut self, body: String) -> &mut Self {
        let desc = TextMessageEventContent::plain(body);
        self.content.description(Some(desc));
        self
    }

    pub fn unset_description(&mut self) -> &mut Self {
        self.content.description(None);
        self
    }

    pub fn sort_order(&mut self, sort_order: u32) -> &mut Self {
        self.content.sort_order(sort_order);
        self
    }

    pub fn color(&mut self, color: Box<Color>) -> &mut Self {
        self.content.color(Some(Box::into_inner(color)));
        self
    }

    pub fn unset_color(&mut self) -> &mut Self {
        self.content.color(None);
        self
    }

    pub fn keywords(&mut self, keywords: &mut [String]) -> &mut Self {
        self.content.keywords(keywords.to_vec());
        self
    }

    pub fn unset_keywords(&mut self) -> &mut Self {
        self.content.keywords(vec![]);
        self
    }

    pub fn categories(&mut self, categories: &mut [String]) -> &mut Self {
        self.content.categories(categories.to_vec());
        self
    }

    pub fn unset_categories(&mut self) -> &mut Self {
        self.content.categories(vec![]);
        self
    }

    pub fn subscribers(&mut self, subscribers: &mut [OwnedUserId]) -> &mut Self {
        self.content.subscribers(subscribers.to_vec());
        self
    }

    pub fn unset_subscribers(&mut self) -> &mut Self {
        self.content.subscribers(vec![]);
        self
    }

    pub async fn send(&self) -> Result<OwnedEventId> {
        let room = self.room.clone();
        let inner = self.content.build()?;
        RUNTIME
            .spawn(async move {
                let resp = room.send(inner, None).await?;
                Ok(resp.event_id)
            })
            .await?
    }
}

#[derive(Clone, Debug)]
pub struct TaskList {
    client: Client,
    room: Room,
    inner: models::TaskList,
}

impl std::ops::Deref for TaskList {
    type Target = models::TaskList;
    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl TaskList {
    pub fn name(&self) -> String {
        self.inner.name.clone()
    }

    pub fn description_text(&self) -> Option<String> {
        self.description.as_ref().map(|t| t.body.clone())
    }

    pub fn subscribers(&self) -> Vec<OwnedUserId> {
        self.inner.subscribers.clone()
    }

    pub fn role(&self) -> Option<String> {
        self.inner
            .role
            .as_ref()
            .and_then(|t| serde_json::to_string(t).ok())
    }

    pub fn sort_order(&self) -> u32 {
        self.inner.sort_order
    }

    pub fn color(&self) -> Option<Color> {
        self.inner.color.clone()
    }

    pub fn time_zone(&self) -> Option<String> {
        self.inner.time_zone.as_ref().map(ToString::to_string)
    }

    pub fn keywords(&self) -> Vec<String> {
        self.inner.keywords.clone()
    }

    pub fn categories(&self) -> Vec<String> {
        self.inner.categories.clone()
    }

    pub fn space(&self) -> Space {
        Space {
            client: self.client.clone(),
            inner: crate::Room {
                room: self.room.clone(),
            },
        }
    }
}

impl TaskList {
    pub fn client(&self) -> &Client {
        &self.client
    }

    pub async fn refresh(&self) -> Result<TaskList> {
        let key = self.inner.event_id().to_string();
        let client = self.client.clone();
        let room = self.room.clone();

        RUNTIME
            .spawn(async move {
                let AnyActerModel::TaskList(inner) = client.store().get(&key).await? else {
                    bail!("Refreshing failed. {key} not a task")
                };
                Ok(TaskList {
                    client,
                    room,
                    inner,
                })
            })
            .await?
    }

    pub fn subscribe(&self) -> Receiver<()> {
        let key = self.inner.event_id().to_string();
        self.client.executor().subscribe(key)
    }

    pub fn task_builder(&self) -> Result<TaskDraft> {
        let Room::Joined(joined) = &self.room else {
            bail!("Can only create tasks in joined rooms");
        };
        let mut content = TaskBuilder::default();
        content.task_list_id(self.event_id().to_owned());
        Ok(TaskDraft {
            client: self.client.clone(),
            room: joined.clone(),
            content,
        })
    }

    pub fn update_builder(&self) -> Result<TaskListUpdateBuilder> {
        let Room::Joined(joined) = &self.room else {
            bail!("Can only update tasks in joined rooms");
        };
        Ok(TaskListUpdateBuilder {
            client: self.client.clone(),
            room: joined.clone(),
            inner: self.inner.updater(),
        })
    }

    pub fn tasks_stats(&self) -> Result<TaskStats> {
        Ok(self.inner.stats().clone())
    }

    pub async fn tasks(&self) -> Result<Vec<Task>> {
        if !self.inner.stats().has_tasks() {
            return Ok(vec![]);
        };
        let tasks_key = self.inner.tasks_key();
        let client = self.client.clone();
        let room = self.room.clone();
        Ok(RUNTIME
            .spawn(async move {
                client
                    .store()
                    .get_list(&tasks_key)
                    .await
                    .into_iter()
                    .flatten()
                    .filter_map(|e| {
                        if let AnyActerModel::Task(inner) = e {
                            Some(Task {
                                client: client.clone(),
                                room: room.clone(),
                                inner,
                            })
                        } else {
                            None
                        }
                    })
                    .collect()
            })
            .await?)
    }

    pub async fn comments(&self) -> Result<crate::CommentsManager> {
        let client = self.client.clone();
        let room = self.room.clone();
        let event_id = self.inner.event_id().to_owned();

        RUNTIME
            .spawn(async move {
                let inner =
                    models::CommentsManager::from_store_and_event_id(client.store(), &event_id)
                        .await;
                Ok(crate::CommentsManager::new(client, room, inner))
            })
            .await?
    }
}

#[derive(Clone, Debug)]
pub struct Task {
    client: Client,
    room: Room,
    inner: models::Task,
}

impl std::ops::Deref for Task {
    type Target = models::Task;
    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

/// helpers for content
impl Task {
    pub fn title(&self) -> String {
        self.inner.title.clone()
    }

    pub fn description_text(&self) -> Option<String> {
        self.inner.description.as_ref().map(|t| t.body.clone())
    }

    pub fn assignees(&self) -> Vec<OwnedUserId> {
        self.inner.assignees.clone()
    }

    pub fn subscribers(&self) -> Vec<OwnedUserId> {
        self.inner.subscribers.clone()
    }

    pub fn sort_order(&self) -> u32 {
        self.inner.sort_order
    }

    pub fn priority(&self) -> Option<u8> {
        Some(match self.inner.priority {
            Priority::Undefined => return None,
            Priority::Highest => 1,
            Priority::SecondHighest => 2,
            Priority::Three => 3,
            Priority::Four => 4,
            Priority::Five => 5,
            Priority::Six => 6,
            Priority::Seven => 7,
            Priority::SecondLowest => 8,
            Priority::Lowest => 9,
        })
    }

    pub fn utc_due(&self) -> Option<UtcDateTime> {
        self.inner.utc_due
    }

    pub fn utc_start(&self) -> Option<UtcDateTime> {
        self.inner.utc_start
    }

    pub fn color(&self) -> Option<Color> {
        self.inner.color.clone()
    }

    pub fn is_done(&self) -> bool {
        self.inner.is_done()
    }

    pub fn progress_percent(&self) -> Option<u8> {
        self.inner.progress_percent
    }

    pub fn keywords(&self) -> Vec<String> {
        self.inner.keywords.clone()
    }

    pub fn categories(&self) -> Vec<String> {
        self.inner.categories.clone()
    }
}

/// Custom functions
impl Task {
    pub async fn refresh(&self) -> Result<Task> {
        let key = self.inner.event_id().to_string();
        let client = self.client.clone();
        let room = self.room.clone();

        RUNTIME
            .spawn(async move {
                let AnyActerModel::Task(inner) = client.store().get(&key).await? else {
                    bail!("Refreshing failed. {key} not a task")
                };
                Ok(Task {
                    client,
                    room,
                    inner,
                })
            })
            .await?
    }

    pub fn update_builder(&self) -> Result<TaskUpdateBuilder> {
        let Room::Joined(joined) = &self.room else {
            bail!("Can only update tasks in joined rooms");
        };
        Ok(TaskUpdateBuilder {
            client: self.client.clone(),
            room: joined.clone(),
            inner: self.inner.updater(),
        })
    }

    pub fn subscribe(&self) -> Receiver<()> {
        let key = self.inner.event_id().to_string();
        self.client.executor().subscribe(key)
    }

    pub async fn comments(&self) -> Result<crate::CommentsManager> {
        let client = self.client.clone();
        let room = self.room.clone();
        let event_id = self.inner.event_id().to_owned();

        RUNTIME
            .spawn(async move {
                let inner =
                    models::CommentsManager::from_store_and_event_id(client.store(), &event_id)
                        .await;
                Ok(crate::CommentsManager::new(client, room, inner))
            })
            .await?
    }
}

#[derive(Clone)]
pub struct TaskDraft {
    client: Client,
    room: Joined,
    content: TaskBuilder,
}

impl TaskDraft {
    pub fn title(&mut self, title: String) -> &mut Self {
        self.content.title(title);
        self
    }

    pub fn description_text(&mut self, body: String) -> &mut Self {
        let desc = TextMessageEventContent::plain(body);
        self.content.description(Some(desc));
        self
    }

    pub fn unset_description(&mut self) -> &mut Self {
        self.content.description(None);
        self
    }

    pub fn sort_order(&mut self, sort_order: u32) -> &mut Self {
        self.content.sort_order(sort_order);
        self
    }

    pub fn color(&mut self, color: Box<Color>) -> &mut Self {
        self.content.color(Some(Box::into_inner(color)));
        self
    }

    pub fn unset_color(&mut self) -> &mut Self {
        self.content.color(None);
        self
    }

    pub fn utc_due_from_rfc3339(&mut self, utc_due: String) -> Result<()> {
        let dt = DateTime::parse_from_rfc3339(&utc_due)?.into();
        self.content.utc_due(Some(dt));
        Ok(())
    }

    pub fn utc_due_from_rfc2822(&mut self, utc_due: String) -> Result<()> {
        let dt = DateTime::parse_from_rfc2822(&utc_due)?.into();
        self.content.utc_due(Some(dt));
        Ok(())
    }

    pub fn utc_due_from_format(&mut self, utc_due: String, format: String) -> Result<()> {
        let dt = DateTime::parse_from_str(&utc_due, &format)?.into();
        self.content.utc_due(Some(dt));
        Ok(())
    }

    pub fn unset_utc_due(&mut self) -> &mut Self {
        self.content.utc_due(None);
        self
    }

    pub fn utc_start_from_rfc3339(&mut self, utc_start: String) -> Result<()> {
        let dt = DateTime::parse_from_rfc3339(&utc_start)?.into();
        self.content.utc_start(Some(dt));
        Ok(())
    }

    pub fn utc_start_from_rfc2822(&mut self, utc_start: String) -> Result<()> {
        let dt = DateTime::parse_from_rfc2822(&utc_start)?.into();
        self.content.utc_start(Some(dt));
        Ok(())
    }

    pub fn utc_start_from_format(&mut self, utc_start: String, format: String) -> Result<()> {
        let dt = DateTime::parse_from_str(&utc_start, &format)?.into();
        self.content.utc_start(Some(dt));
        Ok(())
    }

    pub fn unset_utc_start(&mut self) -> &mut Self {
        self.content.utc_start(None);
        self
    }

    pub fn progress_percent(&mut self, mut progress_percent: u8) -> &mut Self {
        if progress_percent > 100 {
            // ensure the builder won't kill us later
            progress_percent = 100;
        }
        self.content.progress_percent(Some(progress_percent));
        self
    }

    pub fn unset_progress_percent(&mut self) -> &mut Self {
        self.content.progress_percent(None);
        self
    }

    pub fn keywords(&mut self, keywords: &mut [String]) -> &mut Self {
        self.content.keywords(keywords.to_vec());
        self
    }

    pub fn unset_keywords(&mut self) -> &mut Self {
        self.content.keywords(vec![]);
        self
    }

    pub fn categories(&mut self, categories: &mut [String]) -> &mut Self {
        self.content.categories(categories.to_vec());
        self
    }

    pub fn unset_categories(&mut self) -> &mut Self {
        self.content.categories(vec![]);
        self
    }

    pub fn subscribers(&mut self, subscribers: &mut [OwnedUserId]) -> &mut Self {
        self.content.subscribers(subscribers.to_vec());
        self
    }

    pub fn unset_subscribers(&mut self) -> &mut Self {
        self.content.subscribers(vec![]);
        self
    }

    pub fn assignees(&mut self, assignees: &mut [OwnedUserId]) -> &mut Self {
        self.content.assignees(assignees.to_vec());
        self
    }

    pub fn unset_assignees(&mut self) -> &mut Self {
        self.content.assignees(vec![]);
        self
    }

    pub async fn send(&self) -> Result<OwnedEventId> {
        let room = self.room.clone();
        let inner = self.content.build()?;
        RUNTIME
            .spawn(async move {
                let resp = room.send(inner, None).await?;
                Ok(resp.event_id)
            })
            .await?
    }
}

#[derive(Clone)]
pub struct TaskUpdateBuilder {
    client: Client,
    room: Joined,
    inner: tasks::TaskUpdateBuilder,
}

impl TaskUpdateBuilder {
    pub fn title(&mut self, title: String) -> &mut Self {
        self.inner.title(Some(title));
        self
    }

    pub fn unset_title_update(&mut self) -> &mut Self {
        self.inner.title(None);
        self
    }

    pub fn description_text(&mut self, body: String) -> &mut Self {
        let desc = TextMessageEventContent::plain(body);
        self.inner.description(Some(Some(desc)));
        self
    }

    pub fn unset_description(&mut self) -> &mut Self {
        self.inner.description(Some(None));
        self
    }

    pub fn unset_description_update(&mut self) -> &mut Self {
        self.inner
            .description(None::<Option<TextMessageEventContent>>);
        self
    }

    pub fn sort_order(&mut self, sort_order: u32) -> &mut Self {
        self.inner.sort_order(Some(sort_order));
        self
    }

    pub fn unset_sort_order_update(&mut self) -> &mut Self {
        self.inner.sort_order(None);
        self
    }

    pub fn color(&mut self, color: Box<Color>) -> &mut Self {
        self.inner.color(Some(Some(Box::into_inner(color))));
        self
    }

    pub fn unset_color(&mut self) -> &mut Self {
        self.inner.color(Some(None));
        self
    }

    pub fn unset_color_update(&mut self) -> &mut Self {
        self.inner.color(None::<Option<Color>>);
        self
    }

    pub fn keywords(&mut self, keywords: &mut [String]) -> &mut Self {
        self.inner.keywords(Some(keywords.to_vec()));
        self
    }

    pub fn unset_keywords(&mut self) -> &mut Self {
        self.inner.keywords(Some(vec![]));
        self
    }

    pub fn unset_keywords_update(&mut self) -> &mut Self {
        self.inner.keywords(None);
        self
    }

    pub fn categories(&mut self, categories: &mut [String]) -> &mut Self {
        self.inner.categories(Some(categories.to_vec()));
        self
    }

    pub fn unset_categories(&mut self) -> &mut Self {
        self.inner.categories(Some(vec![]));
        self
    }

    pub fn unset_categories_update(&mut self) -> &mut Self {
        self.inner.categories(None);
        self
    }

    pub fn subscribers(&mut self, subscribers: &mut [OwnedUserId]) -> &mut Self {
        self.inner.subscribers(Some(subscribers.to_vec()));
        self
    }

    pub fn unset_subscribers(&mut self) -> &mut Self {
        self.inner.subscribers(Some(vec![]));
        self
    }

    pub fn unset_subscribers_update(&mut self) -> &mut Self {
        self.inner.subscribers(None);
        self
    }

    pub fn assignees(&mut self, assignees: &mut [OwnedUserId]) -> &mut Self {
        self.inner.assignees(Some(assignees.to_vec()));
        self
    }

    pub fn unset_assignees(&mut self) -> &mut Self {
        self.inner.assignees(Some(vec![]));
        self
    }

    pub fn unset_assignees_update(&mut self) -> &mut Self {
        self.inner.assignees(None);
        self
    }

    pub fn mark_done(&mut self) -> &mut Self {
        self.inner.progress_percent(Some(Some(100)));
        self
    }

    pub fn mark_undone(&mut self) -> &mut Self {
        self.inner.progress_percent(Some(None));
        self
    }

    pub fn utc_due_from_rfc3339(&mut self, utc_due: String) -> Result<()> {
        let dt = DateTime::parse_from_rfc3339(&utc_due)?.into();
        self.inner.utc_due(Some(Some(dt)));
        Ok(())
    }

    pub fn utc_due_from_rfc2822(&mut self, utc_due: String) -> Result<()> {
        let dt = DateTime::parse_from_rfc2822(&utc_due)?.into();
        self.inner.utc_due(Some(Some(dt)));
        Ok(())
    }

    pub fn utc_due_from_format(&mut self, utc_due: String, format: String) -> Result<()> {
        let dt = DateTime::parse_from_str(&utc_due, &format)?.into();
        self.inner.utc_due(Some(Some(dt)));
        Ok(())
    }

    pub fn unset_utc_due(&mut self) -> &mut Self {
        self.inner.utc_due(Some(None));
        self
    }

    pub fn unset_utc_due_update(&mut self) -> &mut Self {
        self.inner.utc_due(None);
        self
    }

    pub fn utc_start_from_rfc3339(&mut self, utc_start: String) -> Result<()> {
        let dt = DateTime::parse_from_rfc3339(&utc_start)?.into();
        self.inner.utc_start(Some(Some(dt)));
        Ok(())
    }

    pub fn utc_start_from_rfc2822(&mut self, utc_start: String) -> Result<()> {
        let dt = DateTime::parse_from_rfc2822(&utc_start)?.into();
        self.inner.utc_start(Some(Some(dt)));
        Ok(())
    }

    pub fn utc_start_from_format(&mut self, utc_start: String, format: String) -> Result<()> {
        let dt = DateTime::parse_from_str(&utc_start, &format)?.into();
        self.inner.utc_start(Some(Some(dt)));
        Ok(())
    }

    pub fn unset_utc_start(&mut self) -> &mut Self {
        self.inner.utc_start(Some(None));
        self
    }

    pub fn unset_utc_start_update(&mut self) -> &mut Self {
        self.inner.utc_start(None);
        self
    }

    pub fn progress_percent(&mut self, mut progress_percent: u8) -> &mut Self {
        if progress_percent > 100 {
            // ensure the builder won't kill us later
            progress_percent = 100;
        }
        self.inner.progress_percent(Some(Some(progress_percent)));
        self
    }

    pub fn unset_progress_percent(&mut self) -> &mut Self {
        self.inner.progress_percent(Some(None));
        self
    }

    pub fn unset_progress_percent_update(&mut self) -> &mut Self {
        self.inner.progress_percent(None);
        self
    }

    pub async fn send(&self) -> Result<OwnedEventId> {
        let room = self.room.clone();
        let inner = self.inner.build()?;
        RUNTIME
            .spawn(async move {
                let resp = room.send(inner, None).await?;
                Ok(resp.event_id)
            })
            .await?
    }
}

#[derive(Clone)]
pub struct TaskListUpdateBuilder {
    client: Client,
    room: Joined,
    inner: tasks::TaskListUpdateBuilder,
}

impl TaskListUpdateBuilder {
    pub fn name(&mut self, name: String) -> &mut Self {
        self.inner.name(Some(name));
        self
    }

    pub fn unset_name(&mut self) -> &mut Self {
        self.inner.name(None);
        self
    }

    pub fn description_text(&mut self, body: String) -> &mut Self {
        let desc = TextMessageEventContent::plain(body);
        self.inner.description(Some(desc));
        self
    }

    pub fn unset_description(&mut self) -> &mut Self {
        self.inner.description(Some(None));
        self
    }

    pub fn unset_description_update(&mut self) -> &mut Self {
        self.inner
            .description(None::<Option<TextMessageEventContent>>);
        self
    }

    pub fn sort_order(&mut self, sort_order: u32) -> &mut Self {
        self.inner.sort_order(Some(sort_order));
        self
    }

    pub fn color(&mut self, color: Box<Color>) -> &mut Self {
        self.inner.color(Some(Box::into_inner(color)));
        self
    }

    pub fn unset_color(&mut self) -> &mut Self {
        self.inner.color(Some(None));
        self
    }

    pub fn unset_color_update(&mut self) -> &mut Self {
        self.inner.color(None::<Option<Color>>);
        self
    }

    pub fn keywords(&mut self, keywords: &mut [String]) -> &mut Self {
        self.inner.keywords(Some(keywords.to_vec()));
        self
    }

    pub fn unset_keywords(&mut self) -> &mut Self {
        self.inner.keywords(Some(vec![]));
        self
    }

    pub fn unset_keywords_update(&mut self) -> &mut Self {
        self.inner.keywords(None);
        self
    }

    pub fn categories(&mut self, categories: &mut [String]) -> &mut Self {
        self.inner.categories(Some(categories.to_vec()));
        self
    }

    pub fn unset_categories(&mut self) -> &mut Self {
        self.inner.categories(Some(vec![]));
        self
    }

    pub fn unset_categories_update(&mut self) -> &mut Self {
        self.inner.categories(None);
        self
    }

    pub fn subscribers(&mut self, subscribers: &mut [OwnedUserId]) -> &mut Self {
        self.inner.subscribers(Some(subscribers.to_vec()));
        self
    }

    pub fn unset_subscribers(&mut self) -> &mut Self {
        self.inner.subscribers(Some(vec![]));
        self
    }

    pub fn unset_subscribers_update(&mut self) -> &mut Self {
        self.inner.subscribers(None);
        self
    }

    pub async fn send(&self) -> Result<OwnedEventId> {
        let room = self.room.clone();
        let inner = self.inner.build()?;
        RUNTIME
            .spawn(async move {
                let resp = room.send(inner, None).await?;
                Ok(resp.event_id)
            })
            .await?
    }
}

impl Space {
    pub fn task_list_draft(&self) -> Result<TaskListDraft> {
        let Room::Joined(joined) = &self.inner.room else {
            bail!("You can't create tasks for spaces we are not part on")
        };
        Ok(TaskListDraft {
            client: self.client.clone(),
            room: joined.clone(),
            content: Default::default(),
        })
    }

    pub fn task_list_draft_with_builder(&self, content: TaskListBuilder) -> Result<TaskListDraft> {
        let Room::Joined(joined) = &self.inner.room else {
            bail!("You can't create tasks for spaces we are not part on")
        };
        Ok(TaskListDraft {
            client: self.client.clone(),
            room: joined.clone(),
            content,
        })
    }
}
