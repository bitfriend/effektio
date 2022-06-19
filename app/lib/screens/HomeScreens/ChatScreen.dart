// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, prefer_final_fields, prefer_typing_uninitialized_variables

import 'dart:io';
import 'package:effektio/common/store/chatTheme.dart';
import 'package:effektio/common/store/separatedThemes.dart';
import 'package:effektio/common/widget/AppCommon.dart';
import 'package:effektio/common/widget/customAvatar.dart';
import 'package:effektio/common/widget/emptyMessagesPlaceholder.dart';
import 'package:effektio/controllers/chat_controller.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:effektio_flutter_sdk/effektio_flutter_sdk_ffi.dart'
    show Conversation, FfiListMember;
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:string_validator/string_validator.dart';
import 'package:themed/themed.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:transparent_image/transparent_image.dart';

class ChatScreen extends StatefulWidget {
  final Conversation room;
  final String? user;
  const ChatScreen({Key? key, required this.room, required this.user})
      : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final _user;
  ChatController chatController = ChatController.instance;

  @override
  void initState() {
    _user = types.User(
      id: widget.user!,
    );
    chatController.init(widget.room, _user);
    super.initState();
  }

  @override
  void dispose() {
    Get.delete<ChatController>();
    super.dispose();
  }

  void _handleAttachmentPressed(BuildContext context) {
    showModalBottomSheet<void>(
      backgroundColor: Colors.transparent,
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: SizedBox(
            height: 124,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                GestureDetector(
                  onTap: () => chatController.handleImageSelection(context),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SvgPicture.asset('assets/images/camera.svg'),
                      ),
                      SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Photo',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    ],
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () => chatController.handleFileSelection(context),
                  child: Row(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SvgPicture.asset('assets/images/document.svg'),
                      ),
                      SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'File',
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _avatarBuilder(String userId) {
    return GetBuilder<ChatController>(
      id: 'Avatar',
      builder: (ChatController controller) {
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: CustomAvatar(
            avatar: widget.room.avatar(),
            displayName: null,
            radius: 15,
            isGroup: false,
            stringName: getNameFromId(userId),
          ),
        );
      },
    );
  }

  Widget _imageMessageBuilder(
    types.ImageMessage imageMessage, {
    required int messageWidth,
  }) {
    if (imageMessage.uri.isEmpty) {
      // binary data
      if (imageMessage.metadata?.containsKey('binary') ?? false) {
        return Image.memory(
          imageMessage.metadata?['binary'],
          width: messageWidth.toDouble(),
        );
      } else {
        return Image.memory(
          kTransparentImage,
          width: messageWidth.toDouble(),
        );
      }
    } else if (isURL(imageMessage.uri)) {
      // remote url
      return Image.network(
        imageMessage.uri,
        width: messageWidth.toDouble(),
      );
    } else {
      // local path
      // the image that just sent is displayed from local not remote
      return Image.file(
        File(imageMessage.uri),
        width: messageWidth.toDouble(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppCommonTheme.backgroundColor,
        elevation: 1,
        centerTitle: true,
        toolbarHeight: 70,
        leading: Row(
          children: <Widget>[
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: SvgPicture.asset(
                'assets/images/back_button.svg',
                color: AppCommonTheme.svgIconColor,
              ),
            ),
          ],
        ),
        title: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FutureBuilder<String>(
              future: widget.room.displayName(),
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                if (snapshot.hasData) {
                  return Text(
                    snapshot.requireData,
                    overflow: TextOverflow.clip,
                    style: ChatTheme01.chatTitleStyle,
                  );
                } else {
                  return Text('Loading Name');
                }
              },
            ),
            SizedBox(height: 5),
            FutureBuilder<FfiListMember>(
              future: widget.room.activeMembers(),
              builder: (
                BuildContext context,
                AsyncSnapshot<FfiListMember> snapshot,
              ) {
                if (snapshot.hasData) {
                  return Text(
                    '${snapshot.requireData.length.toString()} ${AppLocalizations.of(context)!.members}',
                    style:
                        ChatTheme01.chatBodyStyle + AppCommonTheme.primaryColor,
                  );
                } else {
                  return Container(
                    height: 15,
                    width: 15,
                    child: CircularProgressIndicator(
                      color: AppCommonTheme.primaryColor,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext ctx) => AlertDialog(
                    title: Text('Leave this room'),
                    content: Text('Are you sure to leave this room?'),
                    actions: [
                      FlatButton(
                        onPressed: () async {
                          await widget.room.leave();
                          Navigator.pop(ctx);
                          Navigator.pop(context); // go back to ChatList page
                        },
                        child: Text('Yes'),
                      ),
                      FlatButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                        },
                        child: Text('No'),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                height: 45,
                width: 45,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: CustomAvatar(
                    avatar: widget.room.avatar(),
                    displayName: widget.room.displayName(),
                    radius: 20,
                    isGroup: true,
                    stringName: '',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(
        () => SafeArea(
          bottom: false,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (chatController.isLoading.isTrue) {
      return Center(
        child: Container(
          height: 15,
          width: 15,
          child: CircularProgressIndicator(
            color: AppCommonTheme.primaryColor,
          ),
        ),
      );
    }
    return GetBuilder<ChatController>(
      id: 'Chat',
      init: chatController,
      builder: (ChatController controller) {
        return Chat(
          l10n: ChatL10nEn(
            emptyChatPlaceholder: '',
            attachmentButtonAccessibilityLabel: '',
            fileButtonAccessibilityLabel: '',
            inputPlaceholder: AppLocalizations.of(context)!.message,
            sendButtonAccessibilityLabel: '',
          ),
          messages: controller.messages,
          onSendPressed: controller.handleSendPressed,
          user: _user,
          //custom avatar builder
          avatarBuilder: _avatarBuilder,
          imageMessageBuilder: _imageMessageBuilder,
          //Whenever users starts typing on keyboard, this will trigger the function
          onTextChanged: (text) async {
            await controller.room.typingNotice(true);
          },
          showUserAvatars: true,
          onAttachmentPressed: () => _handleAttachmentPressed(context),
          onPreviewDataFetched: controller.handlePreviewDataFetched,
          onMessageTap: controller.handleMessageTap,
          onEndReached: controller.handleEndReached,
          onEndReachedThreshold: 0.75,
          emptyState: EmptyPlaceholder(),
          //Custom Theme class, see lib/common/store/chatTheme.dart
          theme: EffektioChatTheme(
            attachmentButtonIcon:
                SvgPicture.asset('assets/images/attachment.svg'),
            sendButtonIcon: SvgPicture.asset('assets/images/sendIcon.svg'),
            seenIcon: SvgPicture.asset('assets/images/seenIcon.svg'),
            deliveredIcon: SvgPicture.asset('assets/images/sentIcon.svg'),
          ),
        );
      },
    );
  }
}
