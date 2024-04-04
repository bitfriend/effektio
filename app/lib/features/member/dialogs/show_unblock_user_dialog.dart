import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:go_router/go_router.dart';

Future<void> showUnblockUserDialog(BuildContext context, Member member) async {
  final userId = member.userId().toString();
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(L10n.of(context).unblockTitle(userId)),
        content: RichText(
          textAlign: TextAlign.left,
          text: TextSpan(
            text: L10n.of(context).youAreAboutToUnblock(userId),
            style: const TextStyle(color: Colors.white, fontSize: 24),
            children: <TextSpan>[
              TextSpan(
                text: L10n.of(context).thisWillAllowThemToContactYouAgain,
              ),
              TextSpan(text: L10n.of(context).continueQuestion),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(),
            child: Text(L10n.of(context).no),
          ),
          TextButton(
            onPressed: () async {
              EasyLoading.show(
                status: L10n.of(context).unblockingUserProgress,
                dismissOnTap: false,
              );
              try {
                await member.unignore();
                EasyLoading.dismiss();
                if (!context.mounted) return;
                EasyLoading.showSuccess(L10n.of(context).unblockingUserSuccess);
              } catch (error) {
                EasyLoading.dismiss();
                if (!context.mounted) return;
                EasyLoading.showError(
                  L10n.of(context).unblockingUserFailed(error),
                  duration: const Duration(seconds: 3),
                );
              }
            },
            child: Text(L10n.of(context).yes),
          ),
        ],
      );
    },
  );
}
