import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:acter/common/providers/common_providers.dart';
import 'package:acter/common/utils/utils.dart';
import 'package:acter/features/chat/models/chat_room_state/chat_room_state.dart';
import 'package:acter/features/chat/providers/chat_providers.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class ChatRoomNotifier extends StateNotifier<ChatRoomState> {
  final Ref ref;
  final Convo convo;
  final String userId;
  TimelineStream? timeline;
  StreamSubscription<TimelineDiff>? subscription;

  ChatRoomNotifier({
    required this.convo,
    required this.userId,
    required this.ref,
  }) : super(const ChatRoomState.loading()) {
    _init();
    _fetchMentionRecords();
  }

  void _init() async {
    try {
      timeline = await convo.timelineStream();
      subscription = timeline?.diffRx().listen((event) async {
        await _parseEvent(event);
      });
      bool hasMore = false;
      do {
        hasMore = await timeline!.paginateBackwards(10);
        // wait for diffRx to be finished
        sleep(const Duration(milliseconds: 100));
      } while (hasMore && ref.read(messagesProvider).length < 10);
      ref.onDispose(() async {
        debugPrint('disposing message stream');
        await subscription?.cancel();
      });
    } catch (e) {
      state = ChatRoomState.error(
        'Some error occured loading room ${e.toString()}',
      );
    }
  }

  void isLoaded() => state = const ChatRoomState.loaded();

  // get the repliedTo field from metadata
  String? _getRepliedTo(types.Message message) {
    final metadata = message.metadata;
    if (metadata == null) {
      return null;
    }
    if (!metadata.containsKey('repliedTo')) {
      return null;
    }
    return metadata['repliedTo'];
  }

  // parses `RoomMessage` event to `types.Message` and updates messages list
  Future<void> _parseEvent(TimelineDiff timelineEvent) async {
    debugPrint('DiffRx: ${timelineEvent.action()}');
    final messagesNotifier = ref.read(messagesProvider.notifier);
    switch (timelineEvent.action()) {
      case 'Append':
        List<RoomMessage> messages = timelineEvent.values()!.toList();
        for (var m in messages) {
          final message = _parseMessage(m);
          if (message == null || message is types.UnsupportedMessage) {
            break;
          }
          messagesNotifier.insertMessage(0, message);
          final repliedTo = _getRepliedTo(message);
          if (repliedTo != null) {
            await _fetchOriginalContent(repliedTo, message.id);
          }
          RoomEventItem? eventItem = m.eventItem();
          if (eventItem != null) {
            await _fetchEventBinary(eventItem.msgType(), message.id);
          }
        }
        break;
      case 'Set':
      case 'Insert':
        RoomMessage m = timelineEvent.value()!;
        final message = _parseMessage(m);
        if (message == null || message is types.UnsupportedMessage) {
          break;
        }
        int index = ref
            .read(messagesProvider)
            .indexWhere((msg) => message.id == msg.id);
        if (index == -1) {
          messagesNotifier.addMessage(message);
        } else {
          // update event may be fetched prior to insert event
          messagesNotifier.replaceMessage(index, message);
        }
        final repliedTo = _getRepliedTo(message);
        if (repliedTo != null) {
          await _fetchOriginalContent(repliedTo, message.id);
        }
        RoomEventItem? eventItem = m.eventItem();
        if (eventItem != null) {
          await _fetchEventBinary(eventItem.msgType(), message.id);
        }
        break;
      case 'Remove':
        int index = timelineEvent.index()!;
        final messages = ref.read(messagesProvider);
        if (index < messages.length) {
          messagesNotifier.removeMessage(messages.length - 1 - index);
        }
        break;
      case 'PushBack':
        RoomMessage m = timelineEvent.value()!;
        final message = _parseMessage(m);
        if (message == null || message is types.UnsupportedMessage) {
          break;
        }
        messagesNotifier.insertMessage(0, message);
        final repliedTo = _getRepliedTo(message);
        if (repliedTo != null) {
          await _fetchOriginalContent(repliedTo, message.id);
        }
        RoomEventItem? eventItem = m.eventItem();
        if (eventItem != null) {
          await _fetchEventBinary(eventItem.msgType(), message.id);
        }
        break;
      case 'PushFront':
        RoomMessage m = timelineEvent.value()!;
        final message = _parseMessage(m);
        if (message == null || message is types.UnsupportedMessage) {
          break;
        }
        messagesNotifier.addMessage(message);
        final repliedTo = _getRepliedTo(message);
        if (repliedTo != null) {
          await _fetchOriginalContent(repliedTo, message.id);
        }
        RoomEventItem? eventItem = m.eventItem();
        if (eventItem != null) {
          await _fetchEventBinary(eventItem.msgType(), message.id);
        }
        break;
      case 'PopBack':
        final messages = ref.read(messagesProvider);
        if (messages.isNotEmpty) {
          messagesNotifier.removeMessage(0);
        }
        break;
      case 'PopFront':
        final messages = ref.read(messagesProvider);
        if (messages.isNotEmpty) {
          messagesNotifier.removeMessage(messages.length - 1);
        }
        break;
      case 'Clear':
        messagesNotifier.reset();
        break;
      case 'Reset':
        break;
      default:
        break;
    }
  }

  Future<void> _fetchMentionRecords() async {
    final activeMembers =
        await ref.read(chatMembersProvider(convo.getRoomIdStr()).future);
    List<Map<String, dynamic>> mentionRecords = [];
    final mentionListNotifier = ref.read(mentionListProvider.notifier);
    for (int i = 0; i < activeMembers.length; i++) {
      String userId = activeMembers[i].userId().toString();
      final profile = activeMembers[i].getProfile();
      Map<String, dynamic> record = {};
      final userName = (await profile.getDisplayName()).text();
      record['display'] = userName ?? simplifyUserId(userId);
      record['link'] = userId;
      mentionRecords.add(record);
      if (i % 3 == 0 || i == activeMembers.length - 1) {
        mentionListNotifier.update((state) => mentionRecords);
      }
    }
  }

  // fetch original content media for reply msg, i.e. text/image/file etc.
  Future<void> _fetchOriginalContent(String originalId, String replyId) async {
    final roomMsg = await convo.getMessage(originalId);

    // reply is allowed for only EventItem not VirtualItem
    // user should be able to get original event as RoomMessage
    RoomEventItem orgEventItem = roomMsg.eventItem()!;
    String eventType = orgEventItem.eventType();
    Map<String, dynamic> repliedToContent = {};
    types.Message? repliedTo;
    switch (eventType) {
      case 'm.policy.rule.room':
      case 'm.policy.rule.server':
      case 'm.policy.rule.user':
      case 'm.room.aliases':
      case 'm.room.avatar':
      case 'm.room.canonical_alias':
      case 'm.room.create':
      case 'm.room.encryption':
      case 'm.room.guest.access':
      case 'm.room.history_visibility':
      case 'm.room.join.rules':
      case 'm.room.name':
      case 'm.room.pinned_events':
      case 'm.room.power_levels':
      case 'm.room.server_acl':
      case 'm.room.third_party_invite':
      case 'm.room.tombstone':
      case 'm.room.topic':
      case 'm.space.child':
      case 'm.space.parent':
        break;
      case 'm.room.encrypted':
        repliedTo = types.CustomMessage(
          author: types.User(id: orgEventItem.sender()),
          createdAt: orgEventItem.originServerTs(),
          id: orgEventItem.eventId(),
          metadata: {
            'itemType': 'event',
            'eventType': eventType,
          },
        );
        break;
      case 'm.room.redaction':
        repliedTo = types.CustomMessage(
          author: types.User(id: orgEventItem.sender()),
          createdAt: orgEventItem.originServerTs(),
          id: orgEventItem.eventId(),
          metadata: {
            'itemType': 'event',
            'eventType': eventType,
          },
        );
        break;
      case 'm.call.answer':
      case 'm.call.candidates':
      case 'm.call.hangup':
      case 'm.call.invite':
        break;
      case 'm.room.message':
        String? orgMsgType = orgEventItem.msgType();
        switch (orgMsgType) {
          case 'm.text':
            TextDesc? description = orgEventItem.textDesc();
            if (description != null) {
              String body = description.body();
              repliedToContent = {
                'content': body,
                'messageLength': body.length,
              };
              repliedTo = types.TextMessage(
                author: types.User(id: orgEventItem.sender()),
                id: originalId,
                createdAt: orgEventItem.originServerTs(),
                text: body,
                metadata: repliedToContent,
              );
            }
            break;
          case 'm.image':
            ImageDesc? description = orgEventItem.imageDesc();
            if (description != null) {
              convo.imageBinary(originalId).then((data) {
                repliedToContent['base64'] = base64Encode(data.asTypedList());
              });
              repliedTo = types.ImageMessage(
                author: types.User(id: orgEventItem.sender()),
                id: originalId,
                createdAt: orgEventItem.originServerTs(),
                name: description.name(),
                size: description.size() ?? 0,
                uri: description.source().url(),
                width: description.width()?.toDouble() ?? 0,
                metadata: repliedToContent,
              );
            }
            break;
          case 'm.audio':
            AudioDesc? description = orgEventItem.audioDesc();
            if (description != null) {
              convo.audioBinary(originalId).then((data) {
                repliedToContent['content'] = base64Encode(data.asTypedList());
              });
              repliedTo = types.AudioMessage(
                author: types.User(id: orgEventItem.sender()),
                id: originalId,
                createdAt: orgEventItem.originServerTs(),
                name: description.name(),
                duration: Duration(seconds: description.duration() ?? 0),
                size: description.size() ?? 0,
                uri: description.source().url(),
                metadata: repliedToContent,
              );
            }
            break;
          case 'm.video':
            VideoDesc? description = orgEventItem.videoDesc();
            if (description != null) {
              convo.videoBinary(originalId).then((data) {
                repliedToContent['content'] = base64Encode(data.asTypedList());
              });
              repliedTo = types.VideoMessage(
                author: types.User(id: orgEventItem.sender()),
                id: originalId,
                createdAt: orgEventItem.originServerTs(),
                name: description.name(),
                size: description.size() ?? 0,
                uri: description.source().url(),
                metadata: repliedToContent,
              );
            }
            break;
          case 'm.file':
            FileDesc? description = orgEventItem.fileDesc();
            if (description != null) {
              repliedToContent = {
                'content': description.name(),
              };
              repliedTo = types.FileMessage(
                author: types.User(id: orgEventItem.sender()),
                id: originalId,
                createdAt: orgEventItem.originServerTs(),
                name: description.name(),
                size: description.size() ?? 0,
                uri: description.source().url(),
                metadata: repliedToContent,
              );
            }
            break;
          case 'm.sticker':
            // user can't do any action about sticker message
            break;
        }
    }

    final messages = ref.read(messagesProvider);
    int index = messages.indexWhere((x) => x.id == replyId);
    if (index != -1 && repliedTo != null) {
      messages[index] = messages[index].copyWith(repliedMessage: repliedTo);
      ref.read(messagesProvider.notifier).state = messages;
    }
  }

  // maps [RoomMessage] to [types.Message].
  types.Message? _parseMessage(RoomMessage message) {
    RoomVirtualItem? virtualItem = message.virtualItem();
    if (virtualItem != null) {
      // should not return null, before we can keep track of index in diff receiver
      return types.UnsupportedMessage(
        author: types.User(id: userId),
        id: UniqueKey().toString(),
        metadata: {
          'itemType': 'virtual',
          'eventType': virtualItem.eventType(),
        },
      );
    }

    // If not virtual item, it should be event item
    RoomEventItem eventItem = message.eventItem()!;

    String eventType = eventItem.eventType();
    String sender = eventItem.sender();
    final author = types.User(
      id: sender,
      firstName: simplifyUserId(sender),
    );
    int createdAt = eventItem.originServerTs(); // in milliseconds
    String eventId = eventItem.eventId();

    String? inReplyTo = eventItem.inReplyTo();
    Map<String, dynamic> reactions = {};
    for (var key in eventItem.reactionKeys()) {
      String k = key.toDartString();
      final records = eventItem.reactionRecords(k);
      if (records != null) {
        reactions[k] = records.toList();
      }
    }
    // state event
    switch (eventType) {
      case 'm.policy.rule.room':
      case 'm.policy.rule.server':
      case 'm.policy.rule.user':
      case 'm.room.aliases':
      case 'm.room.avatar':
      case 'm.room.canonical_alias':
      case 'm.room.create':
      case 'm.room.encryption':
      case 'm.room.guest.access':
      case 'm.room.history_visibility':
      case 'm.room.join.rules':
      case 'm.room.name':
      case 'm.room.pinned_events':
      case 'm.room.power_levels':
      case 'm.room.server_acl':
      case 'm.room.third_party_invite':
      case 'm.room.tombstone':
      case 'm.room.topic':
      case 'm.space.child':
      case 'm.space.parent':
        return types.CustomMessage(
          author: author,
          createdAt: createdAt,
          id: eventId,
          metadata: {
            'itemType': 'event',
            'eventType': eventType,
            'body': eventItem.textDesc()?.body(),
          },
        );
    }

    // message event
    switch (eventType) {
      case 'm.call.answer':
      case 'm.call.candidates':
      case 'm.call.hangup':
      case 'm.call.invite':
        break;
      case 'm.reaction':
      case 'm.room.encrypted':
        final metadata = {'itemType': 'event', 'eventType': eventType};
        if (inReplyTo != null) {
          metadata['repliedTo'] = inReplyTo;
        }
        return types.CustomMessage(
          author: author,
          createdAt: createdAt,
          id: eventId,
          metadata: metadata,
        );
      case 'm.room.redaction':
        final metadata = {'itemType': 'event', 'eventType': eventType};
        if (inReplyTo != null) {
          metadata['repliedTo'] = inReplyTo;
        }
        return types.CustomMessage(
          author: author,
          createdAt: createdAt,
          id: eventId,
          metadata: metadata,
        );
      case 'm.room.member':
        TextDesc? description = eventItem.textDesc();
        if (description != null) {
          String? formattedBody = description.formattedBody();
          String body = description.body(); // always exists
          return types.CustomMessage(
            author: author,
            createdAt: createdAt,
            id: eventId,
            metadata: {
              'itemType': 'event',
              'eventType': eventType,
              'msgType': eventItem.msgType(),
              'body': formattedBody ?? body,
            },
          );
        }
        break;
      case 'm.room.message':
        String? msgType = eventItem.msgType();
        switch (msgType) {
          case 'm.audio':
            AudioDesc? description = eventItem.audioDesc();
            if (description != null) {
              Map<String, dynamic> metadata = {'base64': ''};
              if (inReplyTo != null) {
                metadata['repliedTo'] = inReplyTo;
              }
              if (reactions.isNotEmpty) {
                metadata['reactions'] = reactions;
              }
              return types.AudioMessage(
                author: author,
                createdAt: createdAt,
                duration: Duration(seconds: description.duration() ?? 0),
                id: eventId,
                metadata: metadata,
                mimeType: description.mimetype(),
                name: description.name(),
                size: description.size() ?? 0,
                uri: description.source().url(),
              );
            }
            break;
          case 'm.emote':
            TextDesc? description = eventItem.textDesc();
            if (description != null) {
              String? formattedBody = description.formattedBody();
              String body = description.body(); // always exists
              Map<String, dynamic> metadata = {};
              if (inReplyTo != null) {
                metadata['repliedTo'] = inReplyTo;
              }
              if (reactions.isNotEmpty) {
                metadata['reactions'] = reactions;
              }
              // check whether string only contains emoji(s).
              metadata['enlargeEmoji'] = isOnlyEmojis(body);
              return types.TextMessage(
                author: author,
                createdAt: createdAt,
                id: eventId,
                metadata: metadata,
                text: formattedBody ?? body,
              );
            }
            break;
          case 'm.file':
            FileDesc? description = eventItem.fileDesc();
            if (description != null) {
              Map<String, dynamic> metadata = {};
              if (inReplyTo != null) {
                metadata['repliedTo'] = inReplyTo;
              }
              if (reactions.isNotEmpty) {
                metadata['reactions'] = reactions;
              }
              return types.FileMessage(
                author: author,
                createdAt: createdAt,
                id: eventId,
                metadata: metadata,
                mimeType: description.mimetype(),
                name: description.name(),
                size: description.size() ?? 0,
                uri: description.source().url(),
              );
            }
            break;
          case 'm.image':
            ImageDesc? description = eventItem.imageDesc();
            if (description != null) {
              Map<String, dynamic> metadata = {};
              if (inReplyTo != null) {
                metadata['repliedTo'] = inReplyTo;
              }
              if (reactions.isNotEmpty) {
                metadata['reactions'] = reactions;
              }
              return types.ImageMessage(
                author: author,
                createdAt: createdAt,
                height: description.height()?.toDouble(),
                id: eventId,
                metadata: metadata,
                name: description.name(),
                size: description.size() ?? 0,
                uri: description.source().url(),
                width: description.width()?.toDouble(),
              );
            }
            break;
          case 'm.location':
            LocationDesc? description = eventItem.locationDesc();
            if (description != null) {
              Map<String, dynamic> metadata = {
                'itemType': 'event',
                'eventType': eventType,
                'msgType': msgType,
                'body': description.body(),
                'geoUri': description.geoUri(),
              };
              if (inReplyTo != null) {
                metadata['repliedTo'] = inReplyTo;
              }
              if (reactions.isNotEmpty) {
                metadata['reactions'] = reactions;
              }
              final thumbnailSource = description.thumbnailSource();
              if (thumbnailSource != null) {
                metadata['thumbnailSource'] = thumbnailSource.toString();
              }
              final thumbnailInfo = description.thumbnailInfo();
              final mimetype = thumbnailInfo?.mimetype();
              final size = thumbnailInfo?.size();
              final width = thumbnailInfo?.width();
              final height = thumbnailInfo?.height();
              if (mimetype != null) {
                metadata['thumbnailMimetype'] = mimetype;
              }
              if (size != null) {
                metadata['thumbnailSize'] = size;
              }
              if (width != null) {
                metadata['thumbnailWidth'] = width;
              }
              if (height != null) {
                metadata['thumbnailHeight'] = height;
              }
              return types.CustomMessage(
                author: author,
                createdAt: createdAt,
                id: eventId,
                metadata: metadata,
              );
            }
            break;
          case 'm.notice':
            TextDesc? description = eventItem.textDesc();
            if (description != null) {
              String? formattedBody = description.formattedBody();
              String body = description.body(); // always exists
              return types.TextMessage(
                author: author,
                createdAt: createdAt,
                id: eventId,
                text: formattedBody ?? body,
                metadata: {
                  'itemType': 'event',
                  'eventType': eventType,
                  'msgType': msgType,
                },
              );
            }
            break;
          case 'm.server_notice':
            TextDesc? description = eventItem.textDesc();
            if (description != null) {
              String? formattedBody = description.formattedBody();
              String body = description.body(); // always exists
              return types.TextMessage(
                author: author,
                createdAt: createdAt,
                id: eventId,
                text: formattedBody ?? body,
                metadata: {
                  'itemType': 'event',
                  'eventType': eventType,
                  'msgType': msgType,
                },
              );
            }
            break;
          case 'm.text':
            TextDesc? description = eventItem.textDesc();
            if (description != null) {
              String? formattedBody = description.formattedBody();
              String body = description.body(); // always exists
              Map<String, dynamic> metadata = {};
              if (inReplyTo != null) {
                metadata['repliedTo'] = inReplyTo;
              }
              if (reactions.isNotEmpty) {
                metadata['reactions'] = reactions;
              }
              // check whether string only contains emoji(s).
              metadata['enlargeEmoji'] = isOnlyEmojis(body);
              return types.TextMessage(
                author: author,
                createdAt: createdAt,
                id: eventId,
                metadata: metadata,
                text: formattedBody ?? body,
              );
            }
            break;
          case 'm.video':
            VideoDesc? description = eventItem.videoDesc();
            if (description != null) {
              Map<String, dynamic> metadata = {'base64': ''};
              if (inReplyTo != null) {
                metadata['repliedTo'] = inReplyTo;
              }
              if (reactions.isNotEmpty) {
                metadata['reactions'] = reactions;
              }
              return types.VideoMessage(
                author: author,
                createdAt: createdAt,
                id: eventId,
                metadata: metadata,
                name: description.name(),
                size: description.size() ?? 0,
                uri: description.source().url(),
              );
            }
            break;
          case 'm.key.verification.request':
            break;
        }
        break;
      case 'm.sticker':
        ImageDesc? description = eventItem.imageDesc();
        if (description != null) {
          Map<String, dynamic> metadata = {
            'itemType': 'event',
            'eventType': eventType,
            'name': description.name(),
            'size': description.size() ?? 0,
            'width': description.width()?.toDouble(),
            'height': description.height()?.toDouble(),
            'base64': '',
          };
          if (inReplyTo != null) {
            metadata['repliedTo'] = inReplyTo;
          }
          if (reactions.isNotEmpty) {
            metadata['reactions'] = reactions;
          }
          return types.CustomMessage(
            author: author,
            createdAt: createdAt,
            id: eventId,
            metadata: metadata,
          );
        }
        break;
    }
    return null;
  }

  // fetch event media binary for message.
  Future<void> _fetchEventBinary(String? msgType, String eventId) async {
    switch (msgType) {
      case 'm.audio':
        await _fetchAudioBinary(eventId);
        break;
      case 'm.video':
        await _fetchVideoBinary(eventId);
        break;
    }
  }

  // fetch audio content for message.
  Future<void> _fetchAudioBinary(String eventId) async {
    final messages = ref.read(messagesProvider);
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final data = await convo.audioBinary(eventId);
    int index = messages.indexWhere((x) => x.id == eventId);
    if (index != -1) {
      final metadata = messages[index].metadata ?? {};
      metadata['base64'] = base64Encode(data.asTypedList());
      messages[index] = messages[index].copyWith(metadata: metadata);
      messagesNotifier.replaceMessage(index, messages[index]);
    }
  }

  // fetch video conent for message
  Future<void> _fetchVideoBinary(String eventId) async {
    final messages = ref.read(messagesProvider);
    final messagesNotifier = ref.read(messagesProvider.notifier);
    final data = await convo.videoBinary(eventId);
    int index = messages.indexWhere((x) => x.id == eventId);
    if (index != -1) {
      final metadata = messages[index].metadata ?? {};
      metadata['base64'] = base64Encode(data.asTypedList());
      messages[index] = messages[index].copyWith(metadata: metadata);
      messagesNotifier.replaceMessage(index, messages[index]);
    }
  }

  // Pagination Control
  Future<void> handleEndReached() async {
    bool hasMore = ref.read(paginationProvider);
    if (hasMore) {
      hasMore = await timeline!.paginateBackwards(10);
      ref.read(paginationProvider.notifier).update((state) => hasMore);
      debugPrint('backward pagination has more: $hasMore');
    }
  }
}
