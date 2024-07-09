import 'dart:math';

import 'package:acter/common/providers/room_providers.dart';
import 'package:acter/common/providers/space_providers.dart';
import 'package:acter/common/toolkit/buttons/inline_text_button.dart';
import 'package:acter/common/toolkit/buttons/primary_action_button.dart';
import 'package:acter/common/utils/routes.dart';
import 'package:acter/common/widgets/empty_state_widget.dart';
import 'package:acter/features/space/widgets/related_spaces/helpers.dart';
import 'package:atlas_icons/atlas_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

class SubSpacesPage extends ConsumerWidget {
  static const moreOptionKey = Key('related-spaces-more-actions');
  static const createSubspaceKey = Key('related-spaces-more-create-subspace');
  static const linkSubspaceKey = Key('related-spaces-more-link-subspace');

  final String spaceIdOrAlias;

  const SubSpacesPage({super.key, required this.spaceIdOrAlias});

  Widget _renderTools(
    BuildContext context,
  ) {
    return PopupMenuButton(
      icon: const Icon(Atlas.plus_circle, key: moreOptionKey),
      iconSize: 28,
      color: Theme.of(context).colorScheme.surface,
      itemBuilder: (BuildContext context) => <PopupMenuEntry>[
        PopupMenuItem(
          key: createSubspaceKey,
          onTap: () => context.pushNamed(
            Routes.createSpace.name,
            queryParameters: {'parentSpaceId': spaceIdOrAlias},
          ),
          child: Row(
            children: <Widget>[
              Text(L10n.of(context).createSubspace),
              const Spacer(),
              const Icon(Atlas.connection),
            ],
          ),
        ),
        PopupMenuItem(
          key: linkSubspaceKey,
          onTap: () => context.pushNamed(
            Routes.linkSubspace.name,
            pathParameters: {'spaceId': spaceIdOrAlias},
          ),
          child: Row(
            children: <Widget>[
              Text(L10n.of(context).linkExistingSpace),
              const Spacer(),
              const Icon(Atlas.connection),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => context.pushNamed(
            Routes.linkRecommended.name,
            pathParameters: {'spaceId': spaceIdOrAlias},
          ),
          child: Row(
            children: [
              Text(L10n.of(context).recommendedSpaces),
              const Spacer(),
              const Icon(Atlas.plus_circle),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spaces = ref.watch(spaceRelationsOverviewProvider(spaceIdOrAlias));
    final widthCount = (MediaQuery.of(context).size.width ~/ 300).toInt();
    const int minCount = 3;
    final crossAxisCount = max(1, min(widthCount, minCount));
    final spaceName =
        ref.watch(roomDisplayNameProvider(spaceIdOrAlias)).valueOrNull;
    // get platform of context.
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L10n.of(context).spaces),
            Text(
              '($spaceName)',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
        actions: [
          spaces.when(
            data: (spaces) {
              if (spaces.membership?.canString('CanLinkSpaces') ?? false) {
                return _renderTools(context);
              } else {
                return const SizedBox.shrink();
              }
            },
            error: (error, stack) => Center(
              child: Text(L10n.of(context).loadingFailed(error)),
            ),
            loading: () => Center(
              child: Text(L10n.of(context).loading),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            spaces.when(
              data: (spaces) {
                return renderSubSpaces(
                      context,
                      spaceIdOrAlias,
                      spaces,
                      crossAxisCount: crossAxisCount,
                    ) ??
                    renderFallback(
                      context,
                      spaces.membership?.canString('CanLinkSpaces') ?? false,
                    );
              },
              error: (error, stack) => Center(
                child: Text(L10n.of(context).loadingFailed(error)),
              ),
              loading: () => Center(
                child: Text(L10n.of(context).loading),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget renderFallback(BuildContext context, bool canLinkSpace) {
    return Center(
      heightFactor: 1,
      child: EmptyState(
        title: L10n.of(context).noConnectedSpaces,
        subtitle: L10n.of(context).inConnectedSpaces,
        image: 'assets/images/empty_space.svg',
        primaryButton: canLinkSpace
            ? ActerPrimaryActionButton(
                onPressed: () => context.pushNamed(
                  Routes.createSpace.name,
                  queryParameters: {
                    'parentSpaceId': spaceIdOrAlias,
                  },
                ),
                child: Text(L10n.of(context).createNewSpace),
              )
            : null,
        secondaryButton: canLinkSpace
            ? ActerInlineTextButton(
                onPressed: () => context.pushNamed(
                  Routes.linkSubspace.name,
                  pathParameters: {'spaceId': spaceIdOrAlias},
                ),
                child: Text(L10n.of(context).linkExistingSpace),
              )
            : null,
      ),
    );
  }
}
