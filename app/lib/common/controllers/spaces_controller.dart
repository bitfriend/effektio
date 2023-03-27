import 'package:acter/common/controllers/client_controller.dart';
import 'package:acter/common/models/profile_data.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:core';

Future<ProfileData> getProfileData(Space space) async {
  // FIXME: how to get informed about updates!?!
  final profile = await space.getProfile();
  final name = profile.getDisplayName();
  final displayName = name ?? space.getRoomId();
  if (!profile.hasAvatar()) {
    return ProfileData(displayName, null);
  }
  final avatar = await profile.getAvatar();
  return ProfileData(displayName, avatar);
}

final spaceProfileDataProvider =
    FutureProvider.family<ProfileData, Space>((ref, space) async {
  return await getProfileData(space);
});

final spacesProvider = FutureProvider<List<Space>>((ref) async {
  final client = ref.watch(clientProvider)!;
  // FIXME: how to get informed about updates!?!
  final spaces = await client.spaces();
  return spaces.toList();
});

final spaceProvider =
    FutureProvider.family<Space, String>((ref, roomIdOrAlias) async {
  final client = ref.watch(clientProvider)!;
  // FIXME: fallback to fetching a public data, if not found
  return await client.getSpace(roomIdOrAlias);
});

final spaceMembersProvider =
    FutureProvider.family<List<Member>, String>((ref, roomIdOrAlias) async {
  final space = ref.watch(spaceProvider(roomIdOrAlias)).requireValue;
  final members = await space.activeMembers();
  return members.toList();
});

final spaceRelationsProvider =
    FutureProvider.family<SpaceRelations, String>((ref, spaceId) async {
  final space = ref.watch(spaceProvider(spaceId)).requireValue;
  return await space.spaceRelations();
});

final spaceEventsProvider =
    FutureProvider.family<List<CalendarEvent>, String>((ref, spaceId) async {
  final space = ref.watch(spaceProvider(spaceId)).requireValue;
  return (await space.calendarEvents()).toList();
});

final canonicalParentProvider =
    FutureProvider.family<SpaceWithProfileData?, String>((ref, spaceId) async {
  final relations = ref.watch(spaceRelationsProvider(spaceId)).requireValue;
  final parent = relations.mainParent();
  if (parent == null) {
    print("no parent");
    return null;
  }

  final client = ref.watch(clientProvider)!;
  final space = await client.getSpace(parent.roomId().toString());
  if (space == null) {
    print("no space");
    return null;
  }
  final profile = await getProfileData(space);
  return SpaceWithProfileData(space, profile);
});
