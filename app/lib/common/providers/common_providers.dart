import 'dart:async';

import 'package:acter/common/models/profile_data.dart';
import 'package:acter/common/providers/notifiers/network_notifier.dart';
import 'package:acter/common/utils/utils.dart';
import 'package:acter/features/home/providers/client_providers.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Network/Connectivity Providers
final networkAwareProvider =
    StateNotifierProvider<NetworkStateNotifier, NetworkStatus>(
  (ref) => NetworkStateNotifier(),
);

// Loading Providers
final loadingProvider = StateProvider<bool>((ref) => false);

// Account Profile Providers
class AccountProfile {
  final Account account;
  final ProfileData profile;
  final String? emailAddress; // for only user profile, not room profile

  const AccountProfile(this.account, this.profile, this.emailAddress);
}

Future<ProfileData> getProfileData(Account account) async {
  // FIXME: how to get informed about updates!?!
  final displayName = await account.displayName();
  final avatar = await account.avatar();
  return ProfileData(displayName.text(), avatar.data());
}

final accountProvider = FutureProvider((ref) async {
  final client = ref.watch(clientProvider);
  if (client == null) {
    throw 'No Client found';
  }
  return client.account();
});

final accountProfileProvider = FutureProvider((ref) async {
  final account = await ref.watch(accountProvider.future);
  final profile = await getProfileData(account);
  final emailAddress = await account.emailAddress();
  return AccountProfile(account, profile, emailAddress.text());
});
