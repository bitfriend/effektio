import 'package:acter/common/themes/app_theme.dart';
import 'package:flutter/material.dart';

class SideSheet extends StatelessWidget {
  final String header;
  final Widget? body;
  final List<Widget>? delegates;
  final bool addBackIconButton;
  final bool addCloseIconButton;
  final bool addActions;
  final bool addDivider;
  final Key? confirmActionKey;
  final String confirmActionTitle;
  final String cancelActionTitle;
  final String? closeButtonTooltip;
  final String? backButtonTooltip;
  final List<Widget>? actions;

  final void Function()? confirmActionOnPressed;
  final void Function()? cancelActionOnPressed;

  static const closeKey = Key('sidesheet-close');

  const SideSheet({
    super.key,
    required this.header,
    this.body,
    this.delegates,
    this.actions,
    this.addBackIconButton = false,
    this.addActions = false,
    this.addDivider = false,
    this.cancelActionOnPressed,
    this.confirmActionOnPressed,
    this.cancelActionTitle = 'Cancel',
    this.confirmActionTitle = 'Save',
    this.closeButtonTooltip,
    this.backButtonTooltip,
    this.addCloseIconButton = true,
    this.confirmActionKey,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      elevation: 1,
      color: colorScheme.neutral,
      surfaceTintColor: colorScheme.surfaceTint,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          constraints: BoxConstraints(
            minWidth: 256,
            maxWidth: size.width <= 600 ? size.width : 400,
            minHeight: size.height,
            maxHeight: size.height,
          ),
          // keep space shell top bar to prevent us being covered by front-camera etc.
          padding: const EdgeInsets.only(top: 12),
          child: CustomScrollView(
            shrinkWrap: true,
            slivers: [
              SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _SheetHeader(
                      header: header,
                      addBackIconButton: addBackIconButton,
                      addCloseIconButton: addCloseIconButton,
                      backButtonTooltip: backButtonTooltip,
                      closeButtonTooltip: closeButtonTooltip,
                    ),
                    if (body != null) SingleChildScrollView(child: body),
                    ...(delegates ?? []),
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Visibility(
                  visible: addActions,
                  child: _SheetFooter(
                    addDivider: addDivider,
                    confirmActionTitle: confirmActionTitle,
                    confirmActionKey: confirmActionKey,
                    cancelActionTitle: cancelActionTitle,
                    actions: actions,
                    confirmActionOnPressed: confirmActionOnPressed,
                    cancelActionOnPressed: cancelActionOnPressed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String header;
  final bool addBackIconButton;
  final bool addCloseIconButton;
  final String? backButtonTooltip;
  final String? closeButtonTooltip;

  const _SheetHeader({
    required this.header,
    required this.addBackIconButton,
    required this.addCloseIconButton,
    this.backButtonTooltip,
    this.closeButtonTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(addBackIconButton ? 16 : 24, 16, 16, 16),
      child: Row(
        children: [
          Visibility(
            visible: addBackIconButton,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                tooltip: backButtonTooltip,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Text(
            header,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall,
          ),
          Flexible(
            fit: FlexFit.tight,
            child: SizedBox(width: addCloseIconButton ? 12 : 8),
          ),
          Visibility(
            visible: addCloseIconButton,
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              tooltip: closeButtonTooltip,
              icon: const Icon(Icons.close, key: SideSheet.closeKey),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetFooter extends StatelessWidget {
  final bool addDivider;
  final Key? confirmActionKey;
  final String confirmActionTitle;
  final String cancelActionTitle;
  final List<Widget>? actions;

  final void Function()? confirmActionOnPressed;
  final void Function()? cancelActionOnPressed;

  const _SheetFooter({
    required this.addDivider,
    required this.confirmActionTitle,
    required this.cancelActionTitle,
    this.actions,
    this.confirmActionOnPressed,
    this.cancelActionOnPressed,
    this.confirmActionKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Visibility(
          visible: addDivider,
          child: const Divider(indent: 24, endIndent: 24),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 16, 24, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: actions ??
                [
                  OutlinedButton(
                    onPressed: () {
                      if (cancelActionOnPressed == null) {
                        Navigator.pop(context);
                      } else {
                        cancelActionOnPressed!();
                      }
                    },
                    child: Text(cancelActionTitle),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    key: confirmActionKey,
                    onPressed: confirmActionOnPressed,
                    child: Text(confirmActionTitle),
                  ),
                ],
          ),
        ),
      ],
    );
  }
}
