import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

/// Asks for a new name; resolves to null when cancelled or left blank.
Future<String?> showRenameSavedTorrentDialog({
  required BuildContext context,
  required String currentTitle,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(currentTitle: currentTitle),
  );
}

Future<bool> showDeleteSavedTorrentDialog({
  required BuildContext context,
  required String title,
}) async {
  final l10n = AppLocalizations.of(context);
  final materialL10n = MaterialLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.savedTorrentsDeleteTitle(title)),
      content: Text(l10n.savedTorrentsDeleteMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(materialL10n.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.savedTorrentsDelete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.currentTitle});

  final String currentTitle;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.currentTitle);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    Navigator.of(context).pop(title.isEmpty ? null : title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.savedTorrentsRename),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: l10n.savedTorrentsNameLabel),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(materialL10n.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.savedTorrentsSaveButton),
        ),
      ],
    );
  }
}
