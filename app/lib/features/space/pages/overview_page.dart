import 'package:acter/common/providers/space_providers.dart';
import 'package:acter/common/themes/colors/color_scheme.dart';
import 'package:acter/features/space/widgets/about_card.dart';
import 'package:acter/features/space/widgets/chats_card.dart';
import 'package:acter/features/space/widgets/events_card.dart';
import 'package:acter/features/space/widgets/links_card.dart';
import 'package:acter/features/space/widgets/non_acter_space_card.dart';
import 'package:acter/features/space/widgets/related_spaces_card.dart';
import 'package:acter/features/space/widgets/space_header.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActerSpaceChecker extends ConsumerWidget {
  final Widget child;
  final String spaceId;
  final bool Function(ActerAppSettings?)? expectation;

  const ActerSpaceChecker({
    super.key,
    this.expectation,
    required this.spaceId,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettings = ref.watch(acterAppSettingsProvider(spaceId));
    final expCheck = expectation ?? (a) => a != null;
    return appSettings.when(
      data: (data) => expCheck(data) ? child : const SizedBox.shrink(),
      error: (error, stackTrace) => Text('Failed to load space: $error'),
      loading: () => const SizedBox.shrink(),
    );
  }
}

class SpaceOverview extends ConsumerWidget {
  final String spaceIdOrAlias;

  const SpaceOverview({super.key, required this.spaceIdOrAlias});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // get platform of context.
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: primaryGradient),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SpaceHeader(spaceIdOrAlias: spaceIdOrAlias),
          ),
          SliverToBoxAdapter(
            child: AboutCard(spaceId: spaceIdOrAlias),
          ),
          SliverToBoxAdapter(
            child: ActerSpaceChecker(
              spaceId: spaceIdOrAlias,
              expectation: (a) => a == null,
              child: NonActerSpaceCard(spaceId: spaceIdOrAlias),
            ),
          ),
          SliverToBoxAdapter(
            child: ActerSpaceChecker(
              spaceId: spaceIdOrAlias,
              expectation: (a) => a?.events().active() ?? false,
              child: EventsCard(spaceId: spaceIdOrAlias),
            ),
          ),
          SliverToBoxAdapter(
            child: ActerSpaceChecker(
              spaceId: spaceIdOrAlias,
              expectation: (a) => a?.pins().active() ?? false,
              child: LinksCard(spaceId: spaceIdOrAlias),
            ),
          ),
          SliverToBoxAdapter(
            child: ChatsCard(spaceId: spaceIdOrAlias),
          ),
          RelatedSpacesCard(spaceId: spaceIdOrAlias),
        ],
      ),
    );
  }
}
