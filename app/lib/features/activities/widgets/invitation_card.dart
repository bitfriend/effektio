import 'package:acter/common/providers/room_providers.dart';
import 'package:acter/common/toolkit/buttons/primary_action_button.dart';
import 'package:acter/features/activities/providers/invitations_providers.dart';
import 'package:acter/features/home/providers/client_providers.dart';
import 'package:acter/router/utils.dart';
import 'package:acter_avatar/acter_avatar.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart' show Invitation;
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('a3::activities::invitation_card');

class InvitationCard extends ConsumerStatefulWidget {
  final Invitation invitation;

  const InvitationCard({
    super.key,
    required this.invitation,
  });

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _InvitationCardState();
}

class _InvitationCardState extends ConsumerState<InvitationCard> {
  String? roomTitle;

  @override
  void initState() {
    super.initState();
    _fetchTitle();
  }

  void _fetchTitle() async {
    final title = await widget.invitation.room().displayName();
    setState(() {
      roomTitle = title.text();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          renderTile(context),
          const Divider(indent: 5),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                // Reject Invitation Button
                OutlinedButton(
                  onPressed: () => _onTapDeclineInvite(context),
                  child: Text(L10n.of(context).decline),
                ),
                const SizedBox(width: 15),
                // Accept Invitation Button
                ActerPrimaryActionButton(
                  onPressed: () => _onTapAcceptInvite(context),
                  child: Text(L10n.of(context).accept),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ListTile renderTile(BuildContext context) {
    final isDM = widget.invitation.isDm();
    if (isDM) {
      return renderDmChatTile(context);
    }
    final room = widget.invitation.room();
    if (room.isSpace()) {
      return renderSpaceTile(context);
    }
    return renderGroupChatTile(context);
  }

  ListTile renderSpaceTile(BuildContext context) {
    final roomId = widget.invitation.roomIdStr();
    final roomAvatarInfo = ref.watch(roomAvatarInfoProvider(roomId));
    return ListTile(
      leading: ActerAvatar(
        options: AvatarOptions(
          roomAvatarInfo,
          size: 48,
        ),
      ),
      title: Text(roomAvatarInfo.displayName ?? roomId),
      subtitle: Wrap(
        children: [
          Text(L10n.of(context).invitationToSpace),
          inviter(context),
        ],
      ),
    );
  }

  ListTile renderGroupChatTile(BuildContext context) {
    final roomId = widget.invitation.roomIdStr();
    final roomAvatarInfo = ref.watch(roomAvatarInfoProvider(roomId));
    return ListTile(
      leading: ActerAvatar(
        options: AvatarOptions(
          roomAvatarInfo,
          size: 48,
        ),
      ),
      title: Text(
        roomTitle ?? roomId,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Wrap(
        children: [
          Text(L10n.of(context).invitationToChat),
          inviter(context),
        ],
      ),
    );
  }

  ListTile renderDmChatTile(BuildContext context) {
    final profile =
        ref.watch(invitationUserProfileProvider(widget.invitation)).valueOrNull;
    final senderId = widget.invitation.senderIdStr();
    final roomId = widget.invitation.roomIdStr();
    return ListTile(
      leading: ActerAvatar(
        options: AvatarOptions.DM(
          AvatarInfo(
            uniqueId: roomId,
            displayName: profile?.displayName,
            avatar: profile?.avatar,
          ),
          size: 48,
        ),
      ),
      title: (profile?.displayName) != null
          ? Text('${profile?.displayName} ($senderId)')
          : Text(senderId),
      subtitle: Text(L10n.of(context).invitationToDM),
    );
  }

  Chip inviter(BuildContext context) {
    final profile =
        ref.watch(invitationUserProfileProvider(widget.invitation)).valueOrNull;
    final userId = widget.invitation.senderIdStr();

    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: ActerAvatar(
        options: AvatarOptions.DM(
          AvatarInfo(
            uniqueId: userId,
            displayName: profile?.displayName,
            avatar: profile?.avatar,
          ),
          size: 24,
        ),
      ),
      label: Text(profile?.displayName ?? userId),
    );
  }

  // method for post-process invitation accept
  void _onTapAcceptInvite(BuildContext context) async {
    EasyLoading.show(status: L10n.of(context).joining);
    final client = ref.read(alwaysClientProvider);
    final roomId = widget.invitation.roomIdStr();
    final isSpace = widget.invitation.room().isSpace();
    final lang = L10n.of(context);
    try {
      await widget.invitation.accept();
    } catch (e, s) {
      _log.severe('Failure accepting invite', e, s);
      if (!context.mounted) {
        EasyLoading.dismiss();
        return;
      }
      EasyLoading.showError(
        lang.failedToAcceptInvite(e),
        duration: const Duration(seconds: 3),
      );
      return;
    }

    try {
      // timeout to wait for 10seconds to ensure the room is ready
      await client.waitForRoom(roomId, 10);
    } catch (e, s) {
      _log.warning('Joining $roomId didn’t return within 10 seconds', e, s);
      if (!context.mounted) {
        EasyLoading.dismiss();
        return;
      }
      EasyLoading.showToast(lang.joinedDelayed);
      // do not forward in this case
      return;
    }
    if (!context.mounted) {
      EasyLoading.dismiss();
      return;
    }
    EasyLoading.showToast(lang.joined);
    if (isSpace) {
      goToSpace(context, roomId);
    } else {
      goToChat(context, roomId);
    }
  }

  void _onTapDeclineInvite(BuildContext context) async {
    EasyLoading.show(status: L10n.of(context).rejecting);
    try {
      bool res = await widget.invitation.reject();
      if (!context.mounted) {
        EasyLoading.dismiss();
        return;
      }
      if (res) {
        EasyLoading.showToast(L10n.of(context).rejected);
      } else {
        _log.severe('Failed to reject invitation');
        EasyLoading.showError(
          L10n.of(context).failedToReject,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e, s) {
      _log.severe('Failure reject invite', e, s);
      if (!context.mounted) {
        EasyLoading.dismiss();
        return;
      }
      EasyLoading.showError(
        L10n.of(context).failedToRejectInvite(e),
        duration: const Duration(seconds: 3),
      );
    }
  }
}
