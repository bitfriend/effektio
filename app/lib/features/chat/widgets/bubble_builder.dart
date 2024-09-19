import 'package:acter/common/providers/common_providers.dart';
import 'package:acter/common/providers/room_providers.dart';
import 'package:acter/common/utils/utils.dart';
import 'package:acter/features/chat/models/chat_input_state/chat_input_state.dart';
import 'package:acter/features/chat/providers/chat_providers.dart';
import 'package:acter/features/chat/widgets/custom_message_builder.dart';
import 'package:acter/features/chat/widgets/emoji/emoji_container.dart';
import 'package:acter/features/chat/widgets/emoji/emoji_row.dart';
import 'package:acter/features/chat/widgets/image_message_builder.dart';
import 'package:acter/features/chat/widgets/message_actions.dart';
import 'package:acter/features/chat/widgets/message_metadata_builder.dart';
import 'package:acter/features/chat/widgets/text_message_builder.dart';
import 'package:acter_avatar/acter_avatar.dart';
import 'package:atlas_icons/atlas_icons.dart';
import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:swipe_to/swipe_to.dart';

final _log = Logger('a3::chat::bubble_builder');

class BubbleBuilder extends ConsumerWidget {
  final String roomId;
  final Widget child;
  final types.Message message;
  final bool nextMessageInGroup;
  final bool enlargeEmoji;

  const BubbleBuilder({
    super.key,
    required this.roomId,
    required this.child,
    required this.message,
    required this.nextMessageInGroup,
    required this.enlargeEmoji,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(myUserIdStrProvider);
    final isAuthor = (myId == message.author.id);
    final inputNotifier = ref.read(chatInputProvider.notifier);
    String? eventType = message.metadata?['eventType'];
    bool isMemberEvent = eventType == 'm.room.member';
    bool redactedOrEncrypted = (message is types.CustomMessage) &&
        (eventType == 'm.room.redaction' || eventType == 'm.room.encrypted');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        isMemberEvent
            ? child
            : SwipeTo(
                onRightSwipe: (details) {
                  if (!redactedOrEncrypted) {
                    inputNotifier.setReplyToMessage(message);
                  }
                },
                iconOnRightSwipe: Icons.reply_rounded,
                onLeftSwipe: (details) {
                  if (!redactedOrEncrypted && isAuthor) {
                    inputNotifier.setEditMessage(message);
                  }
                },
                iconOnLeftSwipe: Atlas.pencil_edit_thin,
                child: _ChatBubble(
                  roomId: roomId,
                  message: message,
                  nextMessageInGroup: nextMessageInGroup,
                  enlargeEmoji: enlargeEmoji,
                  child: child,
                ),
              ),
      ],
    );
  }
}

class _ChatBubble extends ConsumerWidget {
  final String roomId;
  final types.Message message;
  final bool nextMessageInGroup;
  final Widget child;
  final bool enlargeEmoji;

  const _ChatBubble({
    required this.roomId,
    required this.message,
    required this.nextMessageInGroup,
    required this.child,
    required this.enlargeEmoji,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(myUserIdStrProvider);
    final isAuthor = (myId == message.author.id);
    final actionsVisible = ref.watch(
      chatInputProvider.select(
        (state) => // only when showing actions and this is the selected message
            state.selectedMessageState == SelectedMessageState.actions &&
            state.selectedMessage?.id == message.id,
      ),
    );
    late List<Widget> children;
    if (actionsVisible) {
      children = [
        EmojiRow(
          roomId: roomId,
          isAuthor: isAuthor,
          onEmojiTap: (String uniqueId, String emoji) {
            ref.read(chatInputProvider.notifier).unsetSelectedMessage();
            toggleReaction(ref, uniqueId, emoji);
          },
          message: message,
        ),
        enlargeEmoji ? child : renderBubble(context, isAuthor),
        MessageActions(
          roomId: roomId,
        ),
      ];
    } else {
      children = [
        const SizedBox(height: 4),
        enlargeEmoji ? child : renderBubble(context, isAuthor),
        EmojiContainer(
          roomId: roomId,
          onToggle: (uniqueId, emoji) => toggleReaction(ref, uniqueId, emoji),
          isAuthor: isAuthor,
          message: message,
          nextMessageInGroup: nextMessageInGroup,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            MessageMetadataBuilder(
              roomId: roomId,
              message: message,
            ),
          ],
        ),
      ];
    }

    return Column(
      crossAxisAlignment:
          isAuthor ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: children,
    );
  }

  Bubble renderBubble(BuildContext context, bool isAuthor) {
    final repliedMessage = message.repliedMessage;
    Widget bubbleChild = repliedMessage == null
        ? child
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: isAuthor
                      ? Theme.of(context).colorScheme.surface.withOpacity(0.3)
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 10,
                        top: 15,
                      ),
                      child: Consumer(
                        builder: (context, ref, child) => replyProfileBuilder(
                          context,
                          ref,
                          repliedMessage,
                        ),
                      ),
                    ),
                    _OriginalMessageBuilder(
                      roomId: roomId,
                      message: message,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              child,
            ],
          );

    return Bubble(
      color: isAuthor
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.surface,
      borderColor: Colors.transparent,
      style: BubbleStyle(
        margin: nextMessageInGroup
            ? const BubbleEdges.symmetric(horizontal: 2)
            : null,
        radius: const Radius.circular(22),
        padding: (message is types.ImageMessage && repliedMessage == null)
            ? const BubbleEdges.all(0)
            : null,
        nip: (nextMessageInGroup || message is types.ImageMessage)
            ? BubbleNip.no
            : !isAuthor
                ? BubbleNip.leftBottom
                : BubbleNip.rightBottom,
        nipHeight: 18,
        nipWidth: 0.5,
        nipRadius: 0,
      ),
      child: bubbleChild,
    );
  }

  Widget replyProfileBuilder(
    BuildContext context,
    WidgetRef ref,
    types.Message repliedMessage,
  ) {
    final authorId = repliedMessage.author.id;
    final replyProfile =
        ref.watch(memberAvatarInfoProvider((userId: authorId, roomId: roomId)));
    return Row(
      children: [
        ActerAvatar(
          options: AvatarOptions.DM(
            replyProfile,
            size: 12,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          replyProfile.displayName ?? '',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Theme.of(context).colorScheme.tertiary,
              ),
        ),
      ],
    );
  }

  // send emoji reaction to message event
  Future<void> toggleReaction(
    WidgetRef ref,
    String uniqueId,
    String emoji,
  ) async {
    try {
      final stream = await ref.read(timelineStreamProvider(roomId).future);
      await stream.toggleReaction(uniqueId, emoji);
    } catch (e, s) {
      _log.severe('Reaction toggle failed', e, s);
    }
  }
}

class _OriginalMessageBuilder extends ConsumerWidget {
  final types.Message message;
  final String roomId;

  const _OriginalMessageBuilder({
    required this.roomId,
    required this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return message.repliedMessage.let((p0) {
          if (p0 is types.TextMessage) {
            final metadata = p0.metadata;
            if (metadata == null) throw 'Replied metadata not available';
            // when original msg is text msg, messageLength should be initialized
            final len = metadata['messageLength'] as int;
            return TextMessageBuilder(
              roomId: roomId,
              message: message.repliedMessage as types.TextMessage,
              messageWidth: (len * 38.5).toInt(),
              isReply: true,
            );
          }
          if (p0 is types.ImageMessage) {
            return Row(
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 50),
                  margin: const EdgeInsets.all(12),
                  child: ImageMessageBuilder(
                    roomId: roomId,
                    message: p0,
                    messageWidth: p0.size.toInt(),
                    isReplyContent: true,
                  ),
                ),
                Text(
                  L10n.of(context).sentAnImage,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            );
          }
          if (p0 is types.FileMessage) {
            final metadata = p0.metadata;
            if (metadata == null) throw 'Replied metadata not available';
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                metadata['content'],
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          if (p0 is types.CustomMessage) {
            return CustomMessageBuilder(
              message: p0,
              messageWidth: 100,
            );
          }
          return null;
        }) ??
        const SizedBox();
  }
}
