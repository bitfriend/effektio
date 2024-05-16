import 'package:acter/features/home/providers/client_providers.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:riverpod/riverpod.dart';

final hasSuperTokensAccess = FutureProvider<bool>((ref) async {
  final asyncVal = ref.watch(superInvitesTokensProvider);
  return !asyncVal
      .hasError; // if we error'd we assume it is not available on the server.
});

final superInvitesTokensProvider =
    FutureProvider<List<SuperInviteToken>>((ref) async {
  final superInvites = ref.watch(superInvitesProvider);
  return (await superInvites.tokens()).toList();
});

final superInvitesProvider = Provider<SuperInvites>((ref) {
  final client = ref.watch(alwaysClientProvider);
  return client.superInvites();
});

/// List of SuperInviteTokens that have the given roomId in their to-invite list
final superInvitesForRoom = FutureProvider.autoDispose
    .family<List<SuperInviteToken>, String>((ref, roomId) async {
  final allInvites = await ref.watch(superInvitesTokensProvider.future);
  return allInvites
      .where(
        (invite) =>
            invite.rooms().map((e) => e.toDartString()).contains(roomId),
      )
      .toList();
});

/// Given the list of rooms this creates a new token with a random key
Future<String> newSuperInviteForRooms(Ref ref, List<String> rooms) async {
  final superInvites = ref.read(superInvitesProvider);
  final builder = superInvites.newTokenUpdater();
  for (final roomId in rooms) {
    builder.addRoom(roomId);
  }
  final token = await superInvites.createOrUpdateToken(builder);
  ref.invalidate(superInvitesTokensProvider);
  return token.token();
}

final superInviteInfoProvider = FutureProvider.autoDispose
    .family<SuperInviteInfo, String>((ref, token) async {
  final superInvites = ref.watch(superInvitesProvider);
  return await superInvites.info(token);
});
