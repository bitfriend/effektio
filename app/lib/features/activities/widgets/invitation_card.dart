import 'package:acter/common/themes/app_theme.dart';
import 'package:acter/features/activities/providers/invitations_providers.dart';
import 'package:acter_avatar/acter_avatar.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart' show Invitation;
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

class InvitationCard extends ConsumerWidget {
  final Invitation invitation;
  final Color avatarColor;

  const InvitationCard({
    super.key,
    required this.invitation,
    required this.avatarColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationProfile = ref.watch(invitationProfileProvider(invitation));
    return invitationProfile.when(
      data: (data) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: ActerAvatar(
                  mode: DisplayMode.Space,
                  avatarInfo: AvatarInfo(
                    uniqueId: data.roomId,
                    displayName: data.displayName,
                    avatar: data.getAvatarImage(),
                  ),
                  size: 20,
                ),
                title: Text(data.roomName ?? data.roomId),
                subtitle: RichText(
                  text: TextSpan(
                    text: AppLocalizations.of(context)!.invitationText2,
                    children: <TextSpan>[
                      TextSpan(text: invitation.sender().toString()),
                    ],
                  ),
                ),
              ),
              Divider(
                color: Theme.of(context).colorScheme.neutral6,
                indent: 15,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  // Reject Invitation Button
                  ElevatedButton(
                    onPressed: () async => await invitation.reject(),
                    child: Text(AppLocalizations.of(context)!.decline),
                  ),
                  // Accept Invitation Button
                  ElevatedButton(
                    onPressed: () =>
                        _onTapAcceptInvite(ref, context, data.roomId),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                        Theme.of(context).colorScheme.success,
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.accept),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      error: (error, stackTrace) => const Text('Error loading invitation'),
      loading: () => const Skeletonizer(
        child: Card(
          child: ListTile(leading: Text('Something')),
        ),
      ),
    );
  }

  // method for post-process invitation accept
  void _onTapAcceptInvite(
    WidgetRef ref,
    BuildContext ctx,
    String roomId,
  ) async {
    EasyLoading.show(status: 'Joining', dismissOnTap: false);
    bool res = await invitation.accept();
    if (!res) {
      EasyLoading.dismiss();
      EasyLoading.showError('Failed to join');
      return;
    }
    EasyLoading.dismiss();
    EasyLoading.showSuccess('Joined');
  }
}
