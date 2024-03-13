import 'package:acter/common/utils/utils.dart';
import 'package:acter/common/widgets/attachments/post_attachment_selection.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart'
    show AttachmentsManager;
import 'package:flutter/material.dart';

// reusable attachment confirmation dialog
void attachmentConfirmationDialog(
  BuildContext ctx,
  AttachmentsManager manager,
  List<AttachmentInfo>? selectedAttachments,
) {
  final size = MediaQuery.of(ctx).size;
  if (selectedAttachments != null && selectedAttachments.isNotEmpty) {
    if (isLargeScreen(ctx)) {
      showAdaptiveDialog(
        context: ctx,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.width * 0.5,
              maxHeight: size.height * 0.5,
            ),
            child: PostAttachmentSelection(
              attachments: selectedAttachments,
              manager: manager,
            ),
          ),
        ),
      );
    } else {
      // dialog doesn't have previous stack as bottom sheet, pop off the previous
      // selection sheet
      Navigator.of(ctx).pop();
      showModalBottomSheet(
        context: ctx,
        builder: (ctx) => PostAttachmentSelection(
          attachments: selectedAttachments,
          manager: manager,
        ),
      );
    }
  }
}
