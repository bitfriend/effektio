import 'package:acter/common/providers/common_providers.dart';
import 'package:acter/common/themes/app_theme.dart';
import 'package:acter/common/themes/chat_theme.dart';
import 'package:acter/common/utils/routes.dart';
import 'package:acter/common/widgets/spaces/space_parent_badge.dart';
import 'package:acter/common/widgets/with_sidebar.dart';
import 'package:acter/features/chat/providers/chat_providers.dart';
import 'package:acter/features/chat/widgets/avatar_builder.dart';
import 'package:acter/features/chat/widgets/bubble_builder.dart';
import 'package:acter/features/chat/widgets/custom_input.dart';
import 'package:acter/features/chat/widgets/custom_message_builder.dart';
import 'package:acter/features/chat/widgets/image_message_builder.dart';
import 'package:acter/features/chat/widgets/rooms_list.dart';
import 'package:acter/features/chat/widgets/text_message_builder.dart';
import 'package:acter/features/home/providers/client_providers.dart';
import 'package:acter/router/providers/router_providers.dart';
import 'package:acter_avatar/acter_avatar.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:atlas_icons/atlas_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class RoomPage extends ConsumerWidget {
  final String roomId;
  const RoomPage({required this.roomId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(chatProvider(roomId)).when(
          data: (convo) => ChatRoom(convo: convo),
          error: (e, s) => Center(child: Text('Loading room failed: $e')),
          loading: () => const Center(child: Text('loading...')),
        );
  }
}

class ChatRoom extends ConsumerStatefulWidget {
  final Convo convo;
  const ChatRoom({
    required this.convo,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<ChatRoom> createState() => _ChatRoomConsumerState();
}

class _ChatRoomConsumerState extends ConsumerState<ChatRoom> {
  void onBackgroundTap() {
    final emojiRowVisible = ref.read(
      chatInputProvider.select((ci) {
        return ci.emojiRowVisible;
      }),
    );
    final inputNotifier = ref.read(chatInputProvider.notifier);
    if (emojiRowVisible) {
      inputNotifier.setCurrentMessageId(null);
      inputNotifier.emojiRowVisible(false);
    }
  }

  Widget avatarBuilder(String userId) {
    return AvatarBuilder(userId: userId);
  }

  Widget textMessageBuilder(
    types.TextMessage m, {
    required int messageWidth,
    required bool showName,
  }) {
    return TextMessageBuilder(
      message: m,
      messageWidth: messageWidth,
    );
  }

  Widget customMessageBuilder(
    types.CustomMessage message, {
    required int messageWidth,
  }) {
    return CustomMessageBuilder(
      message: message,
      messageWidth: messageWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(currentRoutingLocation);
    final client = ref.watch(clientProvider);
    final convo = widget.convo;
    final convoProfile = ref.watch(chatProfileDataProvider(convo));
    final activeMembers = ref.watch(chatMembersProvider(convo.getRoomIdStr()));
    var messages = ref.watch(messagesProvider); //(convo.getRoomIdStr()));
    return OrientationBuilder(
      builder: (context, orientation) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.neutral,
        resizeToAvoidBottomInset: orientation == Orientation.portrait,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 1,
          centerTitle: true,
          toolbarHeight: 70,
          title: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              convoProfile.when(
                data: (profile) {
                  final roomId = convo.getRoomIdStr();
                  return Text(
                    profile.displayName ?? roomId,
                    overflow: TextOverflow.clip,
                    style: Theme.of(context).textTheme.bodyLarge,
                  );
                },
                error: (error, stackTrace) => Text(
                  'Error loading profile $error',
                ),
                loading: () => const CircularProgressIndicator(),
              ),
              const SizedBox(height: 5),
              activeMembers.when(
                data: (members) {
                  int count = members.length;
                  return Text(
                    '$count ${AppLocalizations.of(context)!.members}',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                },
                error: (error, stackTrace) =>
                    Text('Error loading members count $error'),
                loading: () => const CircularProgressIndicator(),
              ),
            ],
          ),
          actions: [
            GestureDetector(
              onTap: () {
                if (!isDesktop || location != Routes.chat.route) {
                  context.pushNamed(
                    Routes.chatProfile.name,
                    pathParameters: {'roomId': convo.getRoomIdStr()},
                  );
                } else {
                  ref.read(showFullSplitView.notifier).update((state) => true);
                }
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SpaceParentBadge(
                  spaceId: convo.getRoomIdStr(),
                  badgeSize: 20,
                  child: convoProfile.when(
                    data: (profile) => ActerAvatar(
                      uniqueId: convo.getRoomIdStr(),
                      mode: DisplayMode.GroupChat,
                      displayName: profile.displayName ?? convo.getRoomIdStr(),
                      avatar: profile.getAvatarImage(),
                      size: 36,
                    ),
                    error: (err, stackTrace) {
                      debugPrint('Failed to load avatar due to $err');
                      return ActerAvatar(
                        uniqueId: convo.getRoomIdStr(),
                        mode: DisplayMode.GroupChat,
                        displayName: convo.getRoomIdStr(),
                        size: 36,
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Chat(
          customBottomWidget: CustomChatInput(convo: convo),
          textMessageBuilder: textMessageBuilder,
          l10n: ChatL10nEn(
            emptyChatPlaceholder: '',
            attachmentButtonAccessibilityLabel: '',
            fileButtonAccessibilityLabel: '',
            inputPlaceholder: AppLocalizations.of(context)!.message,
            sendButtonAccessibilityLabel: '',
          ),
          timeFormat: DateFormat.jm(),
          messages: messages,
          onSendPressed: (types.PartialText partialText) {},
          user: types.User(id: client!.userId().toString()),
          // disable image preview
          disableImageGallery: true,
          // custom avatar builder
          avatarBuilder: avatarBuilder,
          isLastPage: !ref.watch(paginationProvider),
          bubbleBuilder: (
            Widget child, {
            required types.Message message,
            required bool nextMessageInGroup,
          }) =>
              BubbleBuilder(
            convo: convo,
            message: message,
            nextMessageInGroup: nextMessageInGroup,
            enlargeEmoji: message.metadata!['enlargeEmoji'] ?? false,
            child: child,
          ),
          imageMessageBuilder: (
            types.ImageMessage message, {
            required int messageWidth,
          }) =>
              ImageMessageBuilder(
            convo: convo,
            message: message,
            messageWidth: messageWidth,
          ),
          customMessageBuilder: customMessageBuilder,
          showUserAvatars: true,
          onMessageLongPress: handleMessageTap,
          // onEndReached: roomNotifier.handleEndReached,
          onEndReachedThreshold: 0.75,
          onBackgroundTap: onBackgroundTap,
          //Custom Theme class, see lib/common/store/chatTheme.dart
          theme: const ActerChatTheme(
            sendButtonIcon: Icon(Atlas.paper_airplane),
            documentIcon: Icon(Atlas.file_thin, size: 18),
          ),
        ),
      ),
    );
  }

  // message tap action
  Future<void> handleMessageTap(
    BuildContext context,
    types.Message message,
  ) async {
    final inputNotifier = ref.read(chatInputProvider.notifier);
    if (ref.read(chatInputProvider).showReplyView) {
      inputNotifier.toggleReplyView(false);
      inputNotifier.setReplyWidget(null);
    }
    inputNotifier.setCurrentMessageId(message.id);
    inputNotifier.emojiRowVisible(true);
  }
}
