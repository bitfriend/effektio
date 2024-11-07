import 'package:acter/common/providers/common_providers.dart';
import 'package:acter/common/providers/space_providers.dart';
import 'package:acter/common/widgets/acter_search_widget.dart';
import 'package:acter/common/widgets/add_button_with_can_permission.dart';
import 'package:acter/common/widgets/space_name_widget.dart';
import 'package:acter/features/tasks/providers/tasklists_providers.dart';
import 'package:acter/features/tasks/sheets/create_update_task_list.dart';
import 'package:acter/features/tasks/widgets/task_list_widget.dart';
import 'package:acter/features/tasks/widgets/task_lists_empty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TasksListPage extends ConsumerStatefulWidget {
  static const scrollView = Key('space-task-lists');
  static const createNewTaskListKey = Key('tasks-create-list');
  static const taskListsKey = Key('tasks-task-lists');

  final String? spaceId;

  const TasksListPage({
    super.key,
    this.spaceId,
  });

  @override
  ConsumerState<TasksListPage> createState() => _TasksListPageConsumerState();
}

class _TasksListPageConsumerState extends ConsumerState<TasksListPage> {
  String get searchValue => ref.watch(searchValueProvider);
  final ValueNotifier<bool> showCompletedTask = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    final lang = L10n.of(context);
    final spaceId = widget.spaceId;
    return AppBar(
      centerTitle: false,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.tasks),
          if (spaceId != null) SpaceNameWidget(spaceId: spaceId),
        ],
      ),
      actions: [
        ValueListenableBuilder(
          valueListenable: showCompletedTask,
          builder: (context, value, child) {
            return TextButton.icon(
              onPressed: () => showCompletedTask.value = !value,
              icon: Icon(
                value
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              label: Text(value ? lang.hideCompleted : lang.showCompleted),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            );
          },
        ),
        AddButtonWithCanPermission(
          key: TasksListPage.createNewTaskListKey,
          spaceId: spaceId,
          canString: 'CanPostTaskList',
          onPressed: () => showCreateUpdateTaskListBottomSheet(
            context,
            initialSelectedSpace: spaceId,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActerSearchWidget(
          onChanged: (value) {
            final notifier = ref.read(searchValueProvider.notifier);
            notifier.state = value;
          },
          onClear: () {
            final notifier = ref.read(searchValueProvider.notifier);
            notifier.state = '';
          },
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: showCompletedTask,
            builder: (context, value, child) => TaskListWidget(
              taskListProvider: tasksListSearchProvider(
                (spaceId: widget.spaceId, searchText: searchValue),
              ),
              spaceId: widget.spaceId,
              shrinkWrap: false,
              showCompletedTask: showCompletedTask.value,
              emptyState: _taskListsEmptyState(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _taskListsEmptyState() {
    var canAdd = false;
    if (searchValue.isEmpty) {
      final canPostLoader =
          ref.watch(hasSpaceWithPermissionProvider('CanPostTaskList'));
      if (canPostLoader.valueOrNull == true) canAdd = true;
    }
    return TaskListsEmptyState(
      canAdd: canAdd,
      inSearch: searchValue.isNotEmpty,
      spaceId: widget.spaceId,
    );
  }
}
