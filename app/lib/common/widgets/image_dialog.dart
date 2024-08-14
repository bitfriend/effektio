import 'dart:io';
import 'package:acter/features/files/widgets/share_file_button.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zoom_hover_pinch_image/zoom_hover_pinch_image.dart';

class ImageDialog extends ConsumerWidget {
  final String title;
  final File imageFile;

  const ImageDialog({
    super.key,
    required this.title,
    required this.imageFile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            ShareFileButton(file: imageFile),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        body: Center(
          child: Zoom(
            clipBehavior: false,
            child: Image.file(
              imageFile,
              frameBuilder: (
                BuildContext context,
                Widget child,
                int? frame,
                bool wasSynchronouslyLoaded,
              ) {
                if (wasSynchronouslyLoaded) {
                  return child;
                }
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
              errorBuilder: (
                BuildContext context,
                Object url,
                StackTrace? error,
              ) {
                return Text(
                  L10n.of(context).couldNotLoadImage(error.toString()),
                );
              },
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
      ),
    );
  }
}
