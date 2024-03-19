import 'package:acter/common/utils/routes.dart';
import 'package:acter/common/widgets/chat/chat_selector_drawer.dart';
import 'package:acter/common/widgets/checkbox_form_field.dart';
import 'package:acter/common/widgets/input_text_field.dart';
import 'package:acter/common/widgets/sliver_scaffold.dart';
import 'package:acter/common/widgets/spaces/space_selector_drawer.dart';
import 'package:acter/features/settings/super_invites/providers/super_invites_providers.dart';
import 'package:acter/features/settings/super_invites/widgets/to_join_room.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:atlas_icons/atlas_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CreateSuperInviteTokenPage extends ConsumerStatefulWidget {
  static Key tokenFieldKey = const Key('super-invites-create-token-token');
  static Key createDmKey = const Key('super-invites-create-token-create-dm');
  static Key addSpaceKey = const Key('super-invites-create-token-add-space');
  static Key addChatKey = const Key('super-invites-create-token-add-chat');
  static Key submitBtn = const Key('super-invites-create-submitBtn');
  static Key deleteBtn = const Key('super-invites-create-delete');
  static Key deleteConfirm = const Key('super-invites-create-delete-confirm');
  final SuperInviteToken? token;

  const CreateSuperInviteTokenPage({super.key, this.token});

  @override
  ConsumerState<CreateSuperInviteTokenPage> createState() =>
      _CreateSuperInviteTokenPageConsumerState();
}

class _CreateSuperInviteTokenPageConsumerState
    extends ConsumerState<CreateSuperInviteTokenPage> {
  final TextEditingController _tokenController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late SuperInvitesTokenUpdateBuilder tokenUpdater;
  bool isEdit = false;
  int _acceptedCount = 0;
  bool _initialDmCheck = false;
  List<String> _roomIds = [];

  @override
  void initState() {
    super.initState();
    final provider = ref.read(superInvitesProvider);
    if (widget.token != null) {
      // given an update builder we are in an edit mode

      isEdit = true;
      final token = widget.token!;
      _tokenController.text = token.token();
      _roomIds = token.rooms().map((e) => e.toDartString()).toList();
      _acceptedCount = token.acceptedCount();
      _initialDmCheck = token.createDm();
      tokenUpdater = token.updateBuilder();
    } else {
      tokenUpdater = provider.newTokenUpdater();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverScaffold(
      header: isEdit ? 'Edit Invite Code' : 'Create Invite Code',
      addActions: true,
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 15),
              isEdit
                  ? ListTile(
                      title: Text(_tokenController.text),
                      subtitle: Text('Claimed $_acceptedCount times'),
                      trailing: IconButton(
                        key: CreateSuperInviteTokenPage.deleteBtn,
                        icon: const Icon(Atlas.trash_can_thin),
                        onPressed: () => _deleteIt(context),
                      ),
                    )
                  : InputTextField(
                      hintText: 'Code',
                      key: CreateSuperInviteTokenPage.tokenFieldKey,
                      textInputType: TextInputType.text,
                      controller: _tokenController,
                      validator: (String? val) =>
                          (val?.isNotEmpty == true && val!.length < 6)
                              ? 'Code must be at least 6 characters long'
                              : null,
                    ),
              CheckboxFormField(
                key: CreateSuperInviteTokenPage.createDmKey,
                title: const Text('Create DM when redeeming'),
                onChanged: (newValue) =>
                    setState(() => tokenUpdater.createDm(newValue ?? false)),
                initialValue: _initialDmCheck,
              ),
              const Text('Spaces & Chats to add them to'),
              Card(
                child: ListTile(
                  title: ButtonBar(
                    children: [
                      OutlinedButton(
                        key: CreateSuperInviteTokenPage.addSpaceKey,
                        onPressed: () async {
                          final newSpace = await selectSpaceDrawer(
                            context: context,
                            currentSpaceId: null,
                            canCheck: 'CanInvite',
                            title: const Text('Add Space'),
                          );
                          if (newSpace != null) {
                            if (!_roomIds.contains(newSpace)) {
                              tokenUpdater.addRoom(newSpace);
                              setState(
                                () => _roomIds = List.from(_roomIds)
                                  ..add(newSpace),
                              );
                            }
                          }
                        },
                        child: const Text('Add Space'),
                      ),
                      OutlinedButton(
                        key: CreateSuperInviteTokenPage.addChatKey,
                        onPressed: () async {
                          final newSpace = await selectChatDrawer(
                            context: context,
                            currentChatId: null,
                            canCheck: 'CanInvite',
                            title: const Text('Add Chat'),
                          );
                          if (newSpace != null) {
                            if (!_roomIds.contains(newSpace)) {
                              tokenUpdater.addRoom(newSpace);
                              setState(
                                () => _roomIds = List.from(_roomIds)
                                  ..add(newSpace),
                              );
                            }
                          }
                        },
                        child: const Text('Add Chat'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      delegates: [
        ListView.builder(
          shrinkWrap: true,
          itemBuilder: (context, idx) {
            final roomId = _roomIds[idx];
            return RoomToInviteTo(
              roomId: roomId,
              onRemove: () {
                tokenUpdater.removeRoom(roomId);
                setState(
                  () => _roomIds = List.from(_roomIds)..remove(roomId),
                );
              },
            );
          },
          itemCount: _roomIds.length,
        ),
      ],
      confirmActionTitle: isEdit ? 'Save' : 'Create Code',
      confirmActionKey: CreateSuperInviteTokenPage.submitBtn,
      confirmActionOnPressed: _submit,
      cancelActionTitle: 'Cancel',
      cancelActionOnPressed: () =>
          context.canPop() ? context.pop() : context.goNamed(Routes.main.name),
    );
  }

  Future<void> _submit() async {
    EasyLoading.show(status: isEdit ? 'Saving code' : 'Creating code');
    try {
      final tokenTxt = _tokenController.text;
      if (tokenTxt.isNotEmpty) {
        tokenUpdater.token(tokenTxt);
      }
      // all other changes happen on the object itself;
      final provider = ref.read(superInvitesProvider);
      await provider.createOrUpdateToken(tokenUpdater);
      ref.invalidate(superInvitesTokensProvider);
      EasyLoading.dismiss();
      // We are doing as expected, but the lints triggers.
      // ignore: use_build_context_synchronously
      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop(); // pop the create sheet
    } catch (err) {
      EasyLoading.showError(
        isEdit ? 'Saving code failed $err' : 'Creating code failed $err',
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _deleteIt(BuildContext context) async {
    final bool? confirm = await showAdaptiveDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Delete code'),
          content: const Text(
            "Do you really want to irreversibly delete the super invite code? It can't be used again after.",
          ),
          actions: <Widget>[
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: TextButton(
                      onPressed: () => ctx.pop(),
                      child: const Text(
                        'No',
                        style: TextStyle(color: Colors.white, fontSize: 17),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      border: Border.all(color: Colors.red),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextButton(
                      key: CreateSuperInviteTokenPage.deleteConfirm,
                      onPressed: () async {
                        ctx.pop(true);
                      },
                      child: const Text(
                        'Delete ',
                        style: TextStyle(color: Colors.white, fontSize: 17),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (confirm != true) {
      return;
    }

    EasyLoading.show(status: 'Deleting code');
    try {
      final tokenTxt = _tokenController.text;
      // all other changes happen on the object itself;
      final provider = ref.read(superInvitesProvider);
      await provider.delete(tokenTxt);
      ref.invalidate(superInvitesTokensProvider);
      EasyLoading.dismiss();
      // We are doing as expected, but the lints triggers.
      // ignore: use_build_context_synchronously
      if (!context.mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop(); // pop the create sheet
    } catch (err) {
      EasyLoading.showError(
        'Deleting code failed $err',
        duration: const Duration(seconds: 3),
      );
    }
  }
}
