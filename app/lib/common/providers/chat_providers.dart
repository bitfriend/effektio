import 'dart:io';

import 'package:acter/common/models/profile_data.dart';
import 'package:acter/common/providers/notifiers/chat_notifiers.dart';
import 'package:acter/common/providers/space_providers.dart';
import 'package:acter/features/home/providers/client_providers.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Provider the profile data of a the given space, keeps up to date with underlying client
final convoProvider =
    AsyncNotifierProvider.family<AsyncConvoNotifier, Convo?, Convo>(
  () => AsyncConvoNotifier(),
);

// Chat Providers
final chatProfileDataProvider =
    FutureProvider.family<ProfileData, Convo>((ref, convo) async {
  // this ensure we are staying up to dates on updates to convo
  final chat = await ref.watch(convoProvider(convo).future);
  if (chat == null) {
    throw 'Chat not accessible';
  }
  final profile = chat.getProfile();
  final displayName = await profile.getDisplayName();
  final isDm = chat.isDm();
  if (!profile.hasAvatar()) {
    return ProfileData(displayName.text(), null, isDm: isDm);
  }
  final avatar = await profile.getThumbnail(48, 48);
  return ProfileData(displayName.text(), avatar.data(), isDm: isDm);
});

final latestMessageProvider =
    StateNotifierProvider.family<LatestMsgNotifier, RoomMessage?, Convo>(
        (ref, convo) {
  return LatestMsgNotifier(ref, convo);
});

final chatProfileDataProviderById =
    FutureProvider.family<ProfileData, String>((ref, roomId) async {
  final chat = await ref.watch(chatProvider(roomId).future);
  return (await ref.watch(chatProfileDataProvider(chat).future));
});

/// Provider the profile data of a the given space, keeps up to date with underlying client
final chatsProvider =
    StateNotifierProvider<ChatRoomsListNotifier, List<Convo>>((ref) {
  final client = ref.watch(clientProvider);
  if (client == null) {
    throw 'No client found';
  }
  return ChatRoomsListNotifier(ref: ref, client: client);
});

final chatProvider =
    FutureProvider.family<Convo, String>((ref, roomIdOrAlias) async {
  final client = ref.watch(clientProvider)!;
  // FIXME: fallback to fetching a public data, if not found
  return await client.convo(roomIdOrAlias);
});

final chatMembersProvider =
    FutureProvider.family<List<Member>, String>((ref, roomIdOrAlias) async {
  final chat = await ref.watch(chatProvider(roomIdOrAlias).future);
  final members = await chat.activeMembers();
  return members.toList();
});

final relatedChatsProvider = FutureProvider.autoDispose
    .family<List<Convo>, String>((ref, spaceId) async {
  return (await ref.watch(spaceRelationsOverviewProvider(spaceId).future))
      .knownChats;
});

class SelectedChatIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    return null;
  }

  void select(String? input) {
    WidgetsBinding.instance.addPostFrameCallback((Duration duration) {
      state = input;
    });
  }
}

final selectedChatIdProvider =
    NotifierProvider<SelectedChatIdNotifier, String?>(
  () => SelectedChatIdNotifier(),
);

final currentConvoProvider = FutureProvider<Convo?>((ref) async {
  final roomId = ref.watch(selectedChatIdProvider);
  if (roomId == null) {
    throw 'No chat selected';
  }
  return await ref.watch(chatProvider(roomId).future);
});

// Member Providers
// TODO: improve this to be reusable for space and chat members alike.
final memberProfileByIdProvider =
    FutureProvider.family<ProfileData, String>((ref, userId) async {
  final member = await ref.read(memberProvider(userId).future);
  if (member == null) {
    throw 'Member not found';
  }
  return await ref.watch(memberProfileProvider(member).future);
});

final memberProfileProvider =
    FutureProvider.family<ProfileData, Member>((ref, member) async {
  UserProfile profile = member.getProfile();
  OptionString displayName = await profile.getDisplayName();
  final avatar = await profile.getThumbnail(62, 60);
  return ProfileData(displayName.text(), avatar.data());
});

final memberProvider =
    FutureProvider.family<Member?, String>((ref, userId) async {
  final convo = await ref.read(currentConvoProvider.future);
  if (convo == null) {
    throw 'No chat selected';
  }
  return await convo.getMember(userId);
});

final imageFileFromMessageIdProvider =
    FutureProvider.family<File, String>((ref, messageId) async {
  final convo = await ref.read(currentConvoProvider.future);
  // Check if image file is available
  final tempDir = await getTemporaryDirectory();
  var imageFile = File('${tempDir.path}/image-$messageId.jpg');
  var isImageAvailable = await imageFile.exists();

  if (!isImageAvailable) {
    if (convo != null) {
      // If image file is not available on local store then save it
      var buf = await convo
          .mediaBinary(messageId)
          .then((value) => value.asTypedList());
      AsyncValue<Uint8List> imageData = AsyncValue.data(buf);
      if (imageData.asData != null) {
        imageFile.create();
        imageFile.writeAsBytesSync(imageData.asData!.value);
      } else {
        throw 'Unable to load image';
      }
    }
  }
  return imageFile;
});

final videoFileFromMessageIdProvider =
    FutureProvider.family<File, String>((ref, messageId) async {
  final convo = await ref.read(currentConvoProvider.future);
  // Check if video file is available
  final tempDir = await getTemporaryDirectory();
  var videoFile = File('${tempDir.path}/video-$messageId.mp4');
  var isVideoAvailable = await videoFile.exists();

  if (!isVideoAvailable) {
    if (convo != null) {
      // If video file is not available on local store then save it
      var buf = await convo
          .mediaBinary(messageId)
          .then((value) => value.asTypedList());
      AsyncValue<Uint8List> videoData = AsyncValue.data(buf);
      if (videoData.asData != null) {
        videoFile.create();
        videoFile.writeAsBytesSync(videoData.asData!.value);
      } else {
        throw 'Unable to load video';
      }
    }
  }
  return videoFile;
});
