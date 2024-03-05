import 'package:acter/common/utils/utils.dart';
import 'package:acter/common/widgets/html_editor.dart';
import 'package:acter/common/widgets/md_editor_with_preview.dart';
import 'package:acter/features/home/widgets/space_chip.dart';
import 'package:acter/features/pins/providers/pins_provider.dart';
import 'package:acter/features/settings/providers/settings_providers.dart';
import 'package:acter_flutter_sdk/acter_flutter_sdk_ffi.dart' show ActerPin;
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:atlas_icons/atlas_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_matrix_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PinItem extends ConsumerStatefulWidget {
  static const linkFieldKey = Key('edit-pin-link-field');
  static const descriptionFieldKey = Key('edit-pin-description-field');
  static const markdownEditorKey = Key('edit-md-editor-field');
  static const richTextEditorKey = Key('edit-rich-editor-field');
  static const saveBtnKey = Key('pin-edit-save');
  final ActerPin pin;
  const PinItem(this.pin, {super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _PinItemState();
}

class _PinItemState extends ConsumerState<PinItem> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  late TextEditingController _linkController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _buildPinContent();
  }

  // pin content builder (default md-editor)
  void _buildPinContent() {
    final content = widget.pin.content();
    String? formattedBody;
    String markdown = '';
    if (content != null) {
      if (content.formattedBody() != null) {
        formattedBody = content.formattedBody();
      } else {
        markdown = content.body();
      }
    }
    _linkController = TextEditingController(text: widget.pin.url() ?? '');
    _descriptionController = TextEditingController(
      text: formattedBody ?? markdown,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final spaceId = pin.roomIdStr();
    final isLink = pin.isLink();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Form(
        key: _formkey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              alignment: Alignment.topLeft,
              margin: const EdgeInsets.all(8),
              child: SpaceChip(spaceId: spaceId),
            ),
            if (isLink) _buildPinLink(),
            _buildPinDescription(),
          ],
        ),
      ),
    );
  }

  // pin link widget
  Widget _buildPinLink() {
    final pinEdit = ref.watch(pinEditProvider(widget.pin));
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        key: PinItem.linkFieldKey,
        onTap: () async =>
            !pinEdit.editMode ? await openLink(pinEdit.link, context) : null,
        controller: _linkController,
        readOnly: !pinEdit.editMode,
        decoration: const InputDecoration(
          prefixIcon: Icon(Atlas.link_chain_thin, size: 18),
        ),
        validator: (value) {
          if (value != null) {
            final uri = Uri.tryParse(value);
            if (uri == null || !uri.isAbsolute) {
              return 'link is not valid';
            }
          }
          return null;
        },
      ),
    );
  }

  // pin content widget
  Widget _buildPinDescription() {
    final pinEdit = ref.watch(pinEditProvider(widget.pin));
    final pinEditNotifier = ref.watch(pinEditProvider(widget.pin).notifier);
    final labFeature = ref.watch(featuresProvider);
    bool isActive(f) => labFeature.isActive(f);

    if (!isActive(LabsFeature.pinsEditor)) {
      return Visibility(
        visible: pinEdit.editMode,
        replacement: Html(
          key: PinItem.descriptionFieldKey,
          data: _descriptionController.text,
          renderNewlines: true,
          padding: const EdgeInsets.all(8),
        ),
        child: Column(
          children: <Widget>[
            MdEditorWithPreview(
              key: PinItem.markdownEditorKey,
              controller: _descriptionController,
            ),
            Visibility(
              visible: pinEdit.editMode,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: () => pinEditNotifier.setEditMode(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 5),
                  ElevatedButton(
                    key: PinItem.saveBtnKey,
                    onPressed: () async {
                      pinEditNotifier.setEditMode(false);
                      pinEditNotifier.setMarkdown(_descriptionController.text);
                      pinEditNotifier.setLink(_linkController.text);
                      await pinEditNotifier.onSave();
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      final content = widget.pin.content();
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: pinEdit.editMode
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height),
        child: HtmlEditor(
          key: PinItem.richTextEditorKey,
          editable: pinEdit.editMode,
          editorState: content != null
              ? EditorState(
                  document: ActerDocumentHelpers.fromMsgContent(content),
                )
              : null,
          footer: pinEdit.editMode ? null : const SizedBox(),
          onCancel: () => pinEditNotifier.setEditMode(false),
          onSave: (plain, htmlBody) async {
            if (_formkey.currentState!.validate()) {
              pinEditNotifier.setEditMode(false);
              pinEditNotifier.setLink(_linkController.text);
              pinEditNotifier.setMarkdown(plain);
              if (htmlBody != null) {
                pinEditNotifier.setHtml(htmlBody);
              }
              await pinEditNotifier.onSave();
            }
          },
        ),
      );
    }
  }
}