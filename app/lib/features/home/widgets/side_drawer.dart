import 'package:effektio/common/snackbars/not_implemented.dart';
import 'package:effektio/common/themes/seperated_themes.dart';
import 'package:effektio/features/cross_signing/cross_signing.dart';
import 'package:effektio/common/widgets/custom_avatar.dart';
import 'package:effektio/features/home/controllers/home_controller.dart';
import 'package:effektio/features/onboarding/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_icons_null_safety/flutter_icons_null_safety.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:themed/themed.dart';

class SideDrawer extends ConsumerWidget {
  const SideDrawer({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientProvider).requireValue;
    final size = MediaQuery.of(context).size;
    return Drawer(
      backgroundColor: AppCommonTheme.backgroundColor,
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(overscroll: false),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const _HeaderWidget(),
              SizedBox(height: size.height * 0.04),
              const _PinsItem(),
              const _TodoItem(),
              const _VaultsItem(),
              const _EventItem(),
              const _SharedResourcesItem(),
              const _PollsItem(),
              const _GroupBudgetingItem(),
              const _SharedDocumentsItem(),
              const _GalleryItem(),
              const SizedBox(height: 5),
              if (!client.isGuest()) const _LogOutItem(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogOutItem extends ConsumerWidget {
  const _LogOutItem();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: SvgPicture.asset(
        'assets/images/logout.svg',
        width: 25,
        height: 25,
        color: AppCommonTheme.primaryColor,
      ),
      title: Text(
        AppLocalizations.of(context)!.logOut,
        style: SideMenuAndProfileTheme.signOutText,
      ),
      onTap: () {
        ref.read(authControllerProvider.notifier).logOut(context);
        if (Get.isRegistered<CrossSigning>()) {
          var crossSigning = Get.find<CrossSigning>();
          crossSigning.dispose();
          Get.delete<CrossSigning>();
        }
      },
    );
  }
}

class _PinsItem extends StatelessWidget {
  const _PinsItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        FlutterIcons.pin_ent,
        color: Colors.teal[700],
      ),
      title: Text(
        AppLocalizations.of(context)!.pins,
        style: SideMenuAndProfileTheme.sideMenuStyle,
      ),
      onTap: () {
        showNotYetImplementedMsg(
          context,
          'Pins from Sidebar is not implemented yet',
        );
      },
    );
  }
}

class _SharedDocumentsItem extends StatelessWidget {
  const _SharedDocumentsItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(
        'assets/images/shared_documents.svg',
        width: 25,
        height: 25,
        color: Colors.teal[900],
      ),
      title: Text(
        AppLocalizations.of(context)!.sharedDocuments,
        style: SideMenuAndProfileTheme.sideMenuStyleDisabled,
      ),
      onTap: () {
        showNotYetImplementedMsg(
          context,
          'Shared Docs is not implemented yet',
        );
      },
    );
  }
}

class _VaultsItem extends StatelessWidget {
  const _VaultsItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        FlutterIcons.safe_mco,
        color: Colors.teal[700],
      ),
      title: Text(
        AppLocalizations.of(context)!.vault,
        style: SideMenuAndProfileTheme.sideMenuStyleDisabled,
      ),
      onTap: () {
        showNotYetImplementedMsg(
          context,
          'Vault is not implemented yet',
        );
      },
    );
  }
}

class _GroupBudgetingItem extends StatelessWidget {
  const _GroupBudgetingItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(
        'assets/images/group_budgeting.svg',
        width: 25,
        height: 25,
        color: Colors.teal[900],
      ),
      title: Text(
        AppLocalizations.of(context)!.groupBudgeting,
        style: SideMenuAndProfileTheme.sideMenuStyleDisabled,
      ),
      onTap: () {
        showNotYetImplementedMsg(
          context,
          'Co-Budgeting is not implemented yet',
        );
      },
    );
  }
}

class _PollsItem extends StatelessWidget {
  const _PollsItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(
        'assets/images/polls.svg',
        width: 25,
        height: 25,
        color: Colors.teal[900],
      ),
      title: Text(
        AppLocalizations.of(context)!.pollsVotes,
        style: SideMenuAndProfileTheme.sideMenuStyleDisabled,
      ),
      onTap: () {
        showNotYetImplementedMsg(
          context,
          'Polls are not implemented yet',
        );
      },
    );
  }
}

class _SharedResourcesItem extends StatelessWidget {
  const _SharedResourcesItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(
        'assets/images/shared_resources.svg',
        width: 25,
        height: 25,
        color: Colors.teal[900],
      ),
      title: Text(
        AppLocalizations.of(context)!.sharedResource,
        style: SideMenuAndProfileTheme.sideMenuStyleDisabled,
      ),
      onTap: () {
        showNotYetImplementedMsg(
          context,
          'Shared Resources is not implemented yet',
        );
      },
    );
  }
}

class _EventItem extends StatelessWidget {
  const _EventItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(
        'assets/images/event.svg',
        width: 25,
        height: 25,
        color: Colors.teal[900],
      ),
      title: Text(
        AppLocalizations.of(context)!.events,
        style: SideMenuAndProfileTheme.sideMenuStyleDisabled,
      ),
      onTap: () {
        showNotYetImplementedMsg(
          context,
          'Events is not implemented yet',
        );
      },
    );
  }
}

class _GalleryItem extends StatelessWidget {
  const _GalleryItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(
        'assets/images/gallery.svg',
        width: 25,
        height: 25,
        color: Colors.teal[700],
      ),
      title: Text(
        AppLocalizations.of(context)!.gallery,
        style: SideMenuAndProfileTheme.sideMenuStyle,
      ),
      onTap: () {
        Navigator.pushNamed(context, '/gallery');
      },
    );
  }
}

class _TodoItem extends StatelessWidget {
  const _TodoItem();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: SvgPicture.asset(
        'assets/images/task.svg',
        width: 25,
        height: 25,
        color: Colors.teal[700],
      ),
      title: Text(
        AppLocalizations.of(context)!.toDoList,
        style: SideMenuAndProfileTheme.sideMenuStyle,
      ),
      onTap: () {
        Navigator.pushNamed(context, '/todo');
      },
    );
  }
}

class _HeaderWidget extends ConsumerWidget {
  const _HeaderWidget();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(clientProvider).requireValue;
    if (client.isGuest()) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            alignment: Alignment.bottomCenter,
            child: ElevatedButton(
              style: ButtonStyle(
                alignment: Alignment.center,
                backgroundColor: MaterialStateProperty.all<Color>(
                  AppCommonTheme.primaryColor,
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: Text(AppLocalizations.of(context)!.login),
            ),
          ),
          Container(
            alignment: Alignment.bottomCenter,
            child: ElevatedButton(
              style: ButtonStyle(
                alignment: Alignment.center,
                backgroundColor: MaterialStateProperty.all<Color>(
                  AppCommonTheme.primaryColor,
                ),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
              },
              child: Text(AppLocalizations.of(context)!.signUp),
            ),
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: () {
        showNotYetImplementedMsg(
          context,
          'Profile View not implemented yet',
        );
      },
      child: ref.watch(userProfileProvider).when(
            data: (data) {
              return Row(
                children: [
                  Container(
                    margin: const EdgeInsets.all(10),
                    child: CustomAvatar(
                      uniqueKey: client.userId().toString(),
                      radius: 24,
                      cacheHeight: 120,
                      cacheWidth: 120,
                      avatar: data.getAvatar(),
                      displayName: data.getDisplayName(),
                      isGroup: false,
                      stringName: data.getDisplayName()!,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      data.getDisplayName() == null
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: AppCommonTheme.primaryColor,
                              ),
                            )
                          : Text(
                              data.getDisplayName()!,
                              style:
                                  SideMenuAndProfileTheme.sideMenuProfileStyle,
                            ),
                      Text(
                        data.userId().toString(),
                        style: SideMenuAndProfileTheme.sideMenuProfileStyle +
                            const FontSize(14),
                      ),
                    ],
                  ),
                ],
              );
            },
            error: (error, stackTrace) => const Center(
              child: Text('Couldn\'t fetch profile'),
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: AppCommonTheme.primaryColor,
              ),
            ),
          ),
    );
  }
}