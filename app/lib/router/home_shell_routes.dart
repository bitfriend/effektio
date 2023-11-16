import 'package:acter/common/themes/app_theme.dart';
import 'package:acter/common/utils/routes.dart';
import 'package:acter/features/home/pages/dashboard.dart';
import 'package:acter/features/profile/pages/my_profile_page.dart';
import 'package:acter/features/settings/pages/blocked_users.dart';
import 'package:acter/features/settings/pages/email_addresses.dart';
import 'package:acter/features/settings/pages/index_page.dart';
import 'package:acter/features/settings/pages/info_page.dart';
import 'package:acter/features/settings/pages/labs_page.dart';
import 'package:acter/features/settings/pages/licenses_page.dart';
import 'package:acter/features/settings/pages/notifications_page.dart';
import 'package:acter/features/settings/pages/sessions_page.dart';
import 'package:acter/features/space/pages/chats_page.dart';
import 'package:acter/features/space/pages/events_page.dart';
import 'package:acter/features/space/pages/members_page.dart';
import 'package:acter/features/space/pages/overview_page.dart';
import 'package:acter/features/space/pages/pins_page.dart';
import 'package:acter/features/space/pages/related_spaces_page.dart';
import 'package:acter/features/space/pages/tasks_page.dart';
import 'package:acter/features/space/providers/space_navbar_provider.dart';
import 'package:acter/features/space/settings/pages/apps_settings_page.dart';
import 'package:acter/features/space/settings/pages/index_page.dart';
import 'package:acter/features/spaces/pages/join_space.dart';
import 'package:acter/features/spaces/pages/spaces_page.dart';
import 'package:acter/router/router.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

List<RouteBase> makeHomeShellRoutes(ref) {
  final tabKeyNotifier = ref.watch(selectedTabKeyProvider.notifier);
  return <RouteBase>[
    GoRoute(
      name: Routes.main.name,
      path: Routes.main.route,
      redirect: (BuildContext context, GoRouterState state) async {
        // we first check if there is a client available for us to use
        final authGuarded = await authGuardRedirect(context, state);
        if (authGuarded != null) {
          return authGuarded;
        }
        if (context.mounted && isDesktop) {
          return Routes.dashboard.route;
        } else {
          return Routes.updates.route;
        }
      },
    ),

    GoRoute(
      name: Routes.dashboard.name,
      path: Routes.dashboard.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const Dashboard(),
        );
      },
    ),

    // ---- SETTINGS
    GoRoute(
      name: Routes.settings.name,
      path: Routes.settings.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const SettingsMenuPage(),
        );
      },
    ),
    GoRoute(
      name: Routes.licenses.name,
      path: Routes.licenses.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const SettingsLicensesPage(),
        );
      },
    ),
    GoRoute(
      name: Routes.settingsLabs.name,
      path: Routes.settingsLabs.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const SettingsLabsPage(),
        );
      },
    ),
    GoRoute(
      name: Routes.settingNotifications.name,
      path: Routes.settingNotifications.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const NotificationsSettingsPage(),
        );
      },
    ),
    GoRoute(
      name: Routes.info.name,
      path: Routes.info.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const SettingsInfoPage(),
        );
      },
    ),
    GoRoute(
      name: Routes.myProfile.name,
      path: Routes.myProfile.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const MyProfile(),
        );
      },
    ),
    GoRoute(
      name: Routes.settingSessions.name,
      path: Routes.settingSessions.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const SessionsPage(),
        );
      },
    ),
    GoRoute(
      name: Routes.emailAddresses.name,
      path: Routes.emailAddresses.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const EmailAddressesPage(),
        );
      },
    ),
    GoRoute(
      name: Routes.blockedUsers.name,
      path: Routes.blockedUsers.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const BlockedUsersPage(),
        );
      },
    ),

    GoRoute(
      name: Routes.spaceRelatedSpaces.name,
      path: Routes.spaceRelatedSpaces.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        tabKeyNotifier.switchTo(const Key('spaces'));
        return NoTransitionPage(
          key: state.pageKey,
          child: RelatedSpacesPage(
            spaceIdOrAlias: state.pathParameters['spaceId']!,
          ),
        );
      },
    ),
    GoRoute(
      name: Routes.spaceMembers.name,
      path: Routes.spaceMembers.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        tabKeyNotifier.switchTo(const Key('members'));
        return NoTransitionPage(
          key: state.pageKey,
          child: SpaceMembersPage(
            spaceIdOrAlias: state.pathParameters['spaceId']!,
          ),
        );
      },
    ),
    GoRoute(
      name: Routes.spacePins.name,
      path: Routes.spacePins.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        tabKeyNotifier.switchTo(const Key('pins'));
        return NoTransitionPage(
          key: state.pageKey,
          child: SpacePinsPage(
            spaceIdOrAlias: state.pathParameters['spaceId']!,
          ),
        );
      },
    ),
    GoRoute(
      name: Routes.spaceEvents.name,
      path: Routes.spaceEvents.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        tabKeyNotifier.switchTo(const Key('events'));
        return NoTransitionPage(
          key: state.pageKey,
          child: SpaceEventsPage(
            spaceIdOrAlias: state.pathParameters['spaceId']!,
          ),
        );
      },
    ),
    GoRoute(
      name: Routes.spaceChats.name,
      path: Routes.spaceChats.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        tabKeyNotifier.switchTo(const Key('chat'));
        return NoTransitionPage(
          key: state.pageKey,
          child: SpaceChatsPage(
            spaceIdOrAlias: state.pathParameters['spaceId']!,
          ),
        );
      },
    ),
    GoRoute(
      name: Routes.spaceTasks.name,
      path: Routes.spaceTasks.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        ref.read(selectedTabKeyProvider.notifier).switchTo(const Key('tasks'));
        return NoTransitionPage(
          key: state.pageKey,
          child: SpaceTasksPage(
            spaceIdOrAlias: state.pathParameters['spaceId']!,
          ),
        );
      },
    ),
    GoRoute(
      name: Routes.space.name,
      path: Routes.space.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        tabKeyNotifier.switchTo(const Key('overview'));
        return NoTransitionPage(
          key: state.pageKey,
          child: SpaceOverview(
            spaceIdOrAlias: state.pathParameters['spaceId']!,
          ),
        );
      },
    ),
    GoRoute(
      name: Routes.joinSpace.name,
      path: Routes.joinSpace.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const JoinSpacePage(),
        );
      },
    ),
    GoRoute(
      name: Routes.spaces.name,
      path: Routes.spaces.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const SpacesPage(),
        );
      },
    ),
    // ---- Space SETTINGS
    GoRoute(
      name: Routes.spaceSettings.name,
      path: Routes.spaceSettings.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: SpaceSettingsMenuIndexPage(
            spaceId: state.pathParameters['spaceId']!,
          ),
        );
      },
    ),
    GoRoute(
      name: Routes.spaceSettingsApps.name,
      path: Routes.spaceSettingsApps.route,
      redirect: authGuardRedirect,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: SpaceAppsSettingsPage(
            spaceId: state.pathParameters['spaceId']!,
          ),
        );
      },
    ),
  ];
}
