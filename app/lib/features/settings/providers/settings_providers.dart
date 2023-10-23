import 'package:acter/common/providers/common_providers.dart';
import 'package:acter/common/utils/feature_flagger.dart';
import 'package:acter/common/utils/utils.dart';
import 'package:acter/features/home/providers/client_providers.dart';
import 'package:acter/features/settings/providers/notifiers/labs_features.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final featuresProvider =
    StateNotifierProvider<SharedPrefFeaturesNotifier, Features<LabsFeature>>(
        (ref) {
  return SharedPrefFeaturesNotifier(
    'a3.labs',
    Features<LabsFeature>(
      flags: const [],
      defaultOn: LabsFeature.defaults,
    ),
  );
});

final ignoredUsersProvider = FutureProvider<List<UserId>>((ref) async {
  final account = await ref.watch(accountProvider.future);
  return (await account.ignoredUsers()).toList();
});

final pushersProvider = FutureProvider<List<Pusher>>((ref) async {
  final client = ref.watch(clientProvider);
  if (client == null) {
    throw 'No client';
  }
  return (await client.pushers()).toList();
});

final isActiveProvider = StateProvider.family<bool, LabsFeature>(
  (ref, feature) => ref.watch(featuresProvider).isActive(feature),
);

// helper
bool updateFeatureState(ref, f, value) {
  debugPrint('setting $f to $value');
  ref.read(featuresProvider.notifier).setActive(f, value);
  return value;
}
