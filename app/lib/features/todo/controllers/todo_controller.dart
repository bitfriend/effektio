import 'package:effektio/models/Team.dart';
import 'package:effektio/models/ToDoComment.dart';
import 'package:effektio/models/ToDoList.dart';
import 'package:effektio/models/ToDoTask.dart';
import 'package:effektio_flutter_sdk/effektio_flutter_sdk.dart';
import 'package:effektio_flutter_sdk/effektio_flutter_sdk_ffi.dart'
    show
        Client,
        Comment,
        CommentDraft,
        CommentsManager,
        CreateGroupSettings,
        FfiString,
        Group,
        RoomProfile,
        Task,
        TaskList,
        TaskListDraft;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ToDoController extends GetxController {
  final Client client;
  RxList<ToDoList> todos = <ToDoList>[].obs;
  bool cardExpand = false;
  bool expandBtn = false;
  RxBool isLoading = false.obs;
  RxBool commentInput = false.obs;
  RxInt maxLength = double.maxFinite.toInt().obs;
  RxInt taskNameCount = 0.obs;
  RxInt selectedValueIndex = 0.obs;
  Team? selectedTeam;
  FocusNode addTaskNode = FocusNode();
  TextEditingController commentInputCntrl = TextEditingController();

  ToDoController({required this.client}) : super();

  @override
  void onInit() {
    super.onInit();
    getTodoList();
    getTeams();
  }

  /// creates team (group).
  Future<String> createTeam(String name) async {
    final sdk = await EffektioSdk.instance;
    CreateGroupSettings settings = sdk.newGroupSettings(name);
    settings.alias(UniqueKey().toString());
    settings.visibility('Public');
    settings.addInvitee('@sisko:matrix.org');
    String roomId =
        await client.createEffektioGroup(settings).then((id) => id.toString());
    return roomId;
  }

  /// fetches teams (groups) for client.
  Future<List<Team>> getTeams() async {
    final List<Team> teams = [];
    List<Group> listTeams =
        await client.groups().then((groups) => groups.toList());
    if (listTeams.isNotEmpty) {
      for (var team in listTeams) {
        RoomProfile teamProfile = await team.getProfile();
        // Team avatars are yet to be implemented.
        Team item = Team(
          id: team.getRoomId(),
          name: teamProfile.getDisplayName(),
        );
        teams.add(item);
      }
    }
    return teams;
  }

  /// fetches todos for client.
  void getTodoList() async {
    List<Group> groups =
        await client.groups().then((groups) => groups.toList());
    for (var group in groups) {
      RoomProfile grpProfile = await group.getProfile();
      Team team = Team(
        id: group.getRoomId(),
        name: grpProfile.getDisplayName(),
      );
      List<TaskList> taskList =
          await group.taskLists().then((ffiList) => ffiList.toList());
      for (var todo in taskList) {
        List<ToDoTask> tasks = await getTodoTasks(todo);
        ToDoList item = ToDoList(
          index: todo.sortOrder(),
          name: todo.name(),
          team: team,
          categories: [],
          taskDraft: todo.taskBuilder(),
          taskUpdateDraft: todo.updateBuilder(),
          tasks: tasks,
          subscribers: [],
          color: todo.color() as Color?,
          description: todo.descriptionText() ?? '',
          tags: [],
          role: todo.role() ?? '',
          timezone: todo.timeZone() ?? '',
        );
        todos.add(item);
      }
    }
  }

  /// fetches todo tasks.
  Future<List<ToDoTask>> getTodoTasks(TaskList list) async {
    List<ToDoTask> todoTasks = [];
    List<String> assignees = [];
    List<String> subscribers = [];

    var tasksList = await list.tasks().then((tasks) => tasks.toList());
    if (tasksList.isNotEmpty) {
      for (Task task in tasksList) {
        if (task.assignees().isNotEmpty) {
          for (var user in task.subscribers().toList()) {
            assignees.add(user.toString());
          }
        }
        if (task.subscribers().isNotEmpty) {
          for (var user in task.subscribers().toList()) {
            subscribers.add(user.toString());
          }
        }
        CommentsManager commentsManager = await task.comments();
        ToDoTask item = ToDoTask(
          index: task.sortOrder(),
          name: task.title(),
          taskUpdateDraft: task.updateBuilder(),
          commentsManager: commentsManager,
          assignees: assignees,
          categories: asDartStringList(task.categories().toList()) ?? [],
          tags: asDartStringList(task.keywords().toList()) ?? [],
          subscribers: subscribers,
          description: task.descriptionText() ?? '',
          priority: task.priority() ?? 0,
          progressPercent: task.progressPercent() ?? 0,
          due: task.utcDue() != null
              ? DateTime.parse(task.utcDue()!.toRfc3339())
              : null,
        );
        todoTasks.add(item);
      }
    }

    return todoTasks;
  }

  /// fetch comments for todo task.
  Future<List<ToDoComment>> getComments(ToDoTask task) async {
    List<ToDoComment> todoComments = [];
    List<Comment> comments = await task.commentsManager
        .comments()
        .then((ffiList) => ffiList.toList());
    for (Comment comment in comments) {
      ToDoComment item = ToDoComment(
        userId: comment.sender().toString(),
        text: comment.contentText(),
        time: DateTime.fromMillisecondsSinceEpoch(comment.originServerTs()),
      );
      todoComments.add(item);
    }
    todoComments.sort((a, b) => a.time.compareTo(b.time));
    return todoComments;
  }

  /// creates todo for team (group).
  Future<String> createToDoList(
    String teamId,
    String name,
    String? description,
  ) async {
    final Group group = await client.getGroup(teamId);
    final RoomProfile teamProfile = await group.getProfile();
    final Team team = Team(
      id: group.getRoomId(),
      name: teamProfile.getDisplayName(),
    );
    final TaskListDraft listDraft = group.taskListDraft();
    listDraft.name(name);
    listDraft.descriptionText(description ?? '');
    String eventId = await listDraft.send().then((res) => res.toString());
    TaskList list = await client.waitForTaskList(eventId, null);
    final ToDoList newItem = ToDoList(
      name: list.name(),
      team: team,
      description: list.descriptionText() ?? '',
      tasks: [],
      taskDraft: list.taskBuilder(),
      taskUpdateDraft: list.updateBuilder(),
    );
    todos.add(newItem);
    return eventId.toString();
  }

  /// creates todo task.
  Future<String> createToDoTask({
    required String name,
    required DateTime? dueDate,
    required ToDoList list,
  }) async {
    list.taskDraft.title(name);
    if (dueDate != null) {
      list.taskDraft.utcDueFromRfc3339(dueDate.toUtc().toIso8601String());
    }
    final String eventId =
        await list.taskDraft.send().then((res) => res.toString());
    // wait for task to come down to wire.
    final Task task = await client.waitForTask(eventId, null);
    final CommentsManager commentsManager = await task.comments();
    final ToDoTask newItem = ToDoTask(
      name: task.title(),
      progressPercent: task.progressPercent() ?? 0,
      taskUpdateDraft: task.updateBuilder(),
      commentsManager: commentsManager,
      due: task.utcDue() != null
          ? DateTime.parse(
              task.utcDue()!.toRfc3339(),
            )
          : null,
      description: task.descriptionText() ?? '',
      assignees: [],
      subscribers: [],
      categories: [],
      tags: [],
      priority: 0,
    );
    // append new task to existing list.
    List<ToDoTask> tasksList = [...list.tasks, newItem];
    int idx = todos.indexOf(list);

    // update todos.
    todos[idx] = list.copyWith(
      name: list.name,
      team: list.team,
      taskDraft: list.taskDraft,
      taskUpdateDraft: list.taskUpdateDraft,
      tasks: tasksList,
    );
    return eventId;
  }

  /// updates todo task progress.
  Future<String> updateToDoTask(
    ToDoTask task,
    ToDoList list,
    String? name,
    DateTime? due,
    int? progressPercent,
  ) async {
    int updateVal = 0;
    DateTime? completedDate;

    /// should only be null if intent is to mark the task.
    if (progressPercent == null) {
      if (task.progressPercent < 100) {
        task.taskUpdateDraft.markDone();
        updateVal = 100;
      } else {
        task.taskUpdateDraft.markUndone();
      }
    }
    // should only be non-null if task title is updated.
    if (name != null) {
      task.taskUpdateDraft.title(name);
    }
    // should only be non-null if intent is to update due.
    if (due != null) {
      task.taskUpdateDraft.utcDueFromRfc3339(due.toUtc().toIso8601String());
      completedDate = due.toUtc();
    } else {
      task.taskUpdateDraft.unsetUtcDue();
      completedDate = null;
    }
    // send task update.
    String eventId =
        await task.taskUpdateDraft.send().then((eventId) => eventId.toString());
    ToDoTask updateItem = ToDoTask(
      name: name ?? task.name,
      progressPercent: progressPercent ?? updateVal,
      taskUpdateDraft: task.taskUpdateDraft,
      commentsManager: task.commentsManager,
      due: completedDate,
    );
    // update todos.
    int idx = list.tasks.indexOf(task);
    int listIdx = todos.indexOf(list);
    ToDoList newList = list;
    newList.tasks[idx] = task.copyWith(
      name: updateItem.name,
      taskUpdateDraft: updateItem.taskUpdateDraft,
      progressPercent: updateItem.progressPercent,
      commentsManager: updateItem.commentsManager,
      due: updateItem.due,
    );
    todos[listIdx] = newList;
    return eventId;
  }

  void updateButtonIndex(int index) {
    selectedValueIndex.value = index;
  }

  //ToDo list card expand.
  void toggleCardExpand(int index, bool prevState) {
    cardExpand = !prevState;
    update(['list-item-$index']);
  }

  // Completed tasks expand.
  void toggleExpandBtn(index, bool prevState) {
    expandBtn = !prevState;
    update(['list-item-$index']);
  }

  // setter for selected team.
  void setSelectedTeam(Team? val) {
    selectedTeam = val;
    update(['teams']);
  }

  // max words counter for task name.
  void updateWordCount(String val) {
    if (val.isEmpty) {
      taskNameCount.value = 30;
      maxLength.value = double.maxFinite.toInt();
      selectedTeam = null;
      update(['teams']);
    } else {
      List l = val.split(' ');
      if (taskNameCount.value > 0) {
        taskNameCount.value = 30 - l.length;
        maxLength.value = double.maxFinite.toInt();
      } else {
        taskNameCount.value = 30 - l.length;
        maxLength.value = val.length;
      }
      update(['teams']);
    }
  }

  // get completed tasks.
  int getCompletedTasks(ToDoList list) {
    int count = 0;
    for (var item in list.tasks) {
      if (item.progressPercent >= 100) {
        count += 1;
      }
    }
    return count;
  }

  void updateCommentInput(TextEditingController cntrl, String val) {
    cntrl
      ..text = val
      ..selection = TextSelection.fromPosition(
        TextPosition(
          offset: cntrl.text.length,
        ),
      );
    update(['comment-input']);
  }

  // Toggle Comment input view.
  void toggleCommentInput() {
    commentInput.value = !commentInput.value;
  }

  // Update Text controller for task name input
  void updateNameInput(TextEditingController cntrl, String val) {
    cntrl
      ..text = val
      ..selection = TextSelection.fromPosition(
        TextPosition(
          offset: cntrl.text.length,
        ),
      );
    update(['task-name']);
  }

  /// send comment draft to wire.
  Future<String> sendComment(CommentDraft draft, String text) async {
    draft.contentText(text);
    String eventId = await draft.send().then((eventId) => eventId.toString());
    // Wait for comment to come down on wire before refreshing screen.
    Future.delayed(const Duration(milliseconds: 800), () {
      update(['discussion']);
    });
    return eventId;
  }

  ///helper function to convert list ffiString object to DartString.
  List<String>? asDartStringList(List<FfiString> list) {
    if (list.isNotEmpty) {
      final List<String> stringList =
          list.map((ffiString) => ffiString.toDartString()).toList();
      return stringList;
    }
    return null;
  }
}