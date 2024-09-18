import 'package:acter/common/providers/room_providers.dart';
import 'package:acter/common/utils/routes.dart';
import 'package:acter/common/widgets/spaces/space_card.dart';
import 'package:acter/features/categories/model/CategoryModelLocal.dart';
import 'package:acter/features/categories/providers/categories_providers.dart';
import 'package:acter/features/categories/utils/category_utils.dart';
import 'package:acter/features/categories/widgets/category_header_view.dart';
import 'package:acter/features/spaces/providers/space_list_provider.dart';
import 'package:atlas_icons/atlas_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

final _log = Logger('a3::space::sub_spaces');

class SubSpaces extends ConsumerWidget {
  static const moreOptionKey = Key('sub-spaces-more-actions');
  static const createSubspaceKey = Key('sub-spaces-more-create-subspace');
  static const linkSubspaceKey = Key('sub-spaces-more-link-subspace');
  final String spaceId;

  const SubSpaces({super.key, required this.spaceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: _buildAppBarUI(context, ref),
      body: _buildSubSpacesUI(context, ref),
    );
  }

  AppBar _buildAppBarUI(BuildContext context, WidgetRef ref) {
    final spaceName = ref.watch(roomDisplayNameProvider(spaceId)).valueOrNull;
    final membership = ref.watch(roomMembershipProvider(spaceId));
    bool canLinkSpace =
        membership.valueOrNull?.canString('CanLinkSpaces') == true;
    return AppBar(
      centerTitle: false,
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
        IconButton(
          icon: Icon(PhosphorIcons.arrowsClockwise()),
          onPressed: () => ref.invalidate(subSpacesListProvider),
        ),
        if (canLinkSpace) _buildMenuOptions(context),
      ],
    );
  }

  Widget _buildMenuOptions(BuildContext context) {
    return PopupMenuButton(
      icon: Icon(PhosphorIcons.dotsThreeVertical()),
      iconSize: 28,
      color: Theme.of(context).colorScheme.surface,
      itemBuilder: (BuildContext context) => <PopupMenuEntry>[
        PopupMenuItem(
          key: SubSpaces.createSubspaceKey,
          onTap: () => context.pushNamed(
            Routes.createSpace.name,
            queryParameters: {'parentSpaceId': spaceId},
          ),
          child: Row(
            children: <Widget>[
              Icon(PhosphorIcons.plus()),
              const SizedBox(width: 6),
              Text(L10n.of(context).createSubspace),
            ],
          ),
        ),
        PopupMenuItem(
          key: SubSpaces.linkSubspaceKey,
          onTap: () => context.pushNamed(
            Routes.linkSubspace.name,
            pathParameters: {'spaceId': spaceId},
          ),
          child: Row(
            children: <Widget>[
              Icon(PhosphorIcons.link()),
              const SizedBox(width: 6),
              Text(L10n.of(context).linkExistingSpace),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => context.pushNamed(
            Routes.linkRecommended.name,
            pathParameters: {'spaceId': spaceId},
          ),
          child: Row(
            children: [
              const Icon(Atlas.link_select, size: 18),
              const SizedBox(width: 8),
              Text(L10n.of(context).recommendedSpaces),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () => context.pushNamed(
            Routes.organizedCategories.name,
            pathParameters: {
              'spaceId': spaceId,
              'categoriesFor': CategoriesFor.spaces.name,
            },
          ),
          child: Row(
            children: [
              Icon(PhosphorIcons.dotsSixVertical()),
              const SizedBox(width: 6),
              Text(L10n.of(context).organized),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubSpacesUI(BuildContext context, WidgetRef ref) {
    final subSpaceList = ref.watch(subSpacesListProvider(spaceId));

    return subSpaceList.when(
      data: (subSpaceListData) {
        final categoryManager = ref.watch(
          categoryManagerProvider(
            (spaceId: spaceId, categoriesFor: CategoriesFor.spaces),
          ),
        );
        return categoryManager.when(
          data: (categoryManagerData) {
            final List<CategoryModelLocal> categoryList =
                getCategorisedSubSpacesWithoutEmptyList(
              categoryManagerData.categories().toList(),
              subSpaceListData,
            );
            return ListView.builder(
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: categoryList.length,
              itemBuilder: (BuildContext context, int index) {
                return _buildCategoriesList(context, categoryList[index]);
              },
            );
          },
          error: (e, s) {
            _log.severe('Failed to load the space categories', e, s);
            return Center(child: Text(L10n.of(context).loadingFailed(e)));
          },
          loading: () => Center(child: Text(L10n.of(context).loading)),
        );
      },
      error: (e, s) {
        _log.severe('Failed to load the sub-spaces', e, s);
        return Center(child: Text(L10n.of(context).loadingFailed(e)));
      },
      loading: () => Center(child: Text(L10n.of(context).loading)),
    );
  }

  Widget _buildCategoriesList(
    BuildContext context,
    CategoryModelLocal categoryModelLocal,
  ) {
    final entries = categoryModelLocal.entries;
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.only(right: 16),
        initiallyExpanded: true,
        shape: const Border(),
        collapsedBackgroundColor: Colors.transparent,
        title: CategoryHeaderView(categoryModelLocal: categoryModelLocal),
        children: List<Widget>.generate(
          entries.length,
          (index) => SpaceCard(
            roomId: entries[index],
            showParents: false,
            showVisibilityMark: true,
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          ),
        ),
      ),
    );
  }
}
