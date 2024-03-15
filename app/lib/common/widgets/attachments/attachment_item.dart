import 'package:acter/common/providers/attachment_providers.dart';
import 'package:acter/common/widgets/redact_content.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart'
    show Attachment, FfiBufferUint8, MsgContent;
import 'package:atlas_icons/atlas_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Attachment item UI
class AttachmentItem extends ConsumerWidget {
  final Attachment attachment;
  final bool canRedact;
  const AttachmentItem({
    super.key,
    required this.attachment,
    this.canRedact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var msgContent = attachment.msgContent();
    String type = attachment.typeStr();
    final eventId = attachment.attachmentIdStr();
    final roomId = attachment.roomIdStr();
    final sender = attachment.sender();
    return Stack(
      children: [
        _buildAttachmentItem(msgContent, type),
        Positioned(
          top: -12,
          right: -12,
          child: Visibility(
            visible: canRedact,
            child: IconButton(
              onPressed: () async {
                await showRedactionWidget(context, eventId, roomId, sender);

                /// FIXME: attachment redacted models aren't handled,
                /// forcibly refreshing attachments
                ref.invalidate(attachmentsProvider);
              },
              icon: const Icon(Atlas.minus_circle_thin, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> showRedactionWidget(
    BuildContext context,
    String eventId,
    String roomId,
    String senderId,
  ) async {
    await showAdaptiveDialog(
      context: context,
      builder: (context) => RedactContentWidget(
        eventId: eventId,
        roomId: roomId,
        senderId: senderId,
        isSpace: true,
      ),
    );
  }

  Widget _buildAttachmentItem(MsgContent msgContent, String type) {
    if (type == 'image') {
      return AttachmentContainer(
        name: msgContent.body(),
        child: _ImageAttachment(attachment: attachment),
      );
    } else if (type == 'video') {
      return AttachmentContainer(
        name: msgContent.body(),
        child: const Center(
          child: Icon(Atlas.file_video_thin),
        ),
      );
    } else if (type == 'audio') {
      return AttachmentContainer(
        name: msgContent.body(),
        child: const Center(
          child: Icon(Atlas.file_audio_thin),
        ),
      );
    } else {
      return AttachmentContainer(
        name: msgContent.body(),
        child: const Center(child: Icon(Atlas.file_thin)),
      );
    }
  }
}

// outer attachment container UI
class AttachmentContainer extends ConsumerWidget {
  const AttachmentContainer({
    super.key,
    required this.name,
    required this.child,
  });
  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final containerColor = Theme.of(context).colorScheme.background;
    final borderColor = Theme.of(context).colorScheme.primary;
    final containerTextStyle = Theme.of(context).textTheme.bodySmall;
    return Container(
      height: 100,
      width: 100,
      padding: const EdgeInsets.fromLTRB(3, 3, 3, 0),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(child: child),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            child: Text(
              name,
              style:
                  containerTextStyle!.copyWith(overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

// image attachment UI
class _ImageAttachment extends StatefulWidget {
  final Attachment attachment;
  const _ImageAttachment({required this.attachment});

  @override
  State<_ImageAttachment> createState() => _ImageAttachmentPreviewState();
}

class _ImageAttachmentPreviewState extends State<_ImageAttachment> {
  late Future<FfiBufferUint8> attachmentImage;

  @override
  void initState() {
    super.initState();
    _getAttachmentImage();
  }

  void _getAttachmentImage() {
    attachmentImage = widget.attachment.sourceBinary(null);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: attachmentImage.then((value) => value.asTypedList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
            ),
          );
        } else {
          return Placeholder(
            child: Text('Error loading image ${snapshot.error}'),
          );
        }
      },
    );
  }
}
