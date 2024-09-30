import 'package:acter/common/models/types.dart';
import 'package:acter/common/providers/common_providers.dart';
import 'package:acter/features/activities/providers/invitations_providers.dart';
import 'package:acter/features/home/providers/client_providers.dart';
import 'package:riverpod/riverpod.dart';

final hasActivitiesProvider = StateProvider((ref) {
  final invitations = ref.watch(invitationListProvider);
  if (invitations.isNotEmpty) {
    return UrgencyBadge.important;
  }
  final syncStatus = ref.watch(syncStateProvider);
  if (syncStatus.errorMsg != null) {
    return UrgencyBadge.important;
  }
  if (ref.watch(hasUnconfirmedEmailAddresses)) {
    return UrgencyBadge.important;
  }
  return UrgencyBadge.none;
});

final hasUnconfirmedEmailAddresses = StateProvider((ref) {
  final emailAddresses = ref.watch(emailAddressesProvider).valueOrNull;
  return emailAddresses?.unconfirmed.isNotEmpty == true;
});
