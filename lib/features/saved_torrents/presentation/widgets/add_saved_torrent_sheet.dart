import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/torrent/magnet_link.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';

typedef SaveTorrentCallback =
    Future<SaveTorrentResult> Function({required String magnet, String? title});

/// Opens the "add magnet" form as a bottom sheet (compact) or dialog (wider).
///
/// Resolves to the save result, or null when the user cancelled.
Future<SaveTorrentResult?> showAddSavedTorrentSheet({
  required BuildContext context,
  required SaveTorrentCallback onSave,
  String? initialMagnet,
}) {
  return showAdaptiveSheet<SaveTorrentResult>(
    context: context,
    builder: (_) =>
        AddSavedTorrentForm(onSave: onSave, initialMagnet: initialMagnet),
  );
}

class AddSavedTorrentForm extends StatefulWidget {
  const AddSavedTorrentForm({
    required this.onSave,
    this.initialMagnet,
    super.key,
  });

  static const magnetFieldKey = Key('add_saved_torrent_magnet_field');
  static const nameFieldKey = Key('add_saved_torrent_name_field');
  static const saveButtonKey = Key('add_saved_torrent_save_button');

  final SaveTorrentCallback onSave;
  final String? initialMagnet;

  @override
  State<AddSavedTorrentForm> createState() => _AddSavedTorrentFormState();
}

class _AddSavedTorrentFormState extends State<AddSavedTorrentForm> {
  final _magnetController = TextEditingController();
  final _nameController = TextEditingController();

  /// The name the form filled in from `dn`; replaced again only while the
  /// user has not typed their own name.
  String _autoName = '';
  String _lastMagnetText = '';
  bool _showInvalid = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMagnet;
    if (initial != null) {
      _magnetController.text = initial;
      _lastMagnetText = initial;
      _syncNameFromMagnet();
    }
    _magnetController.addListener(_onMagnetChanged);
  }

  @override
  void dispose() {
    _magnetController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onMagnetChanged() {
    // The controller also notifies on selection and focus changes; only an
    // edit of the text should clear the validation error.
    if (_magnetController.text == _lastMagnetText) return;
    _lastMagnetText = _magnetController.text;
    _syncNameFromMagnet();
    setState(() => _showInvalid = false);
  }

  void _syncNameFromMagnet() {
    if (_nameController.text != _autoName) return;
    _autoName = MagnetLink.tryParse(_magnetController.text)?.displayName ?? '';
    _nameController.text = _autoName;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    _magnetController.text = text;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await widget.onSave(
      magnet: _magnetController.text,
      title: _nameController.text,
    );
    if (!mounted) return;
    if (result is SaveTorrentInvalidMagnet) {
      setState(() {
        _saving = false;
        _showInvalid = true;
      });
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canSave = _magnetController.text.trim().isNotEmpty && !_saving;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.savedTorrentsAddTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: AddSavedTorrentForm.magnetFieldKey,
                    controller: _magnetController,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 4,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l10n.savedTorrentsMagnetLabel,
                      hintText: 'magnet:?xt=urn:btih:…',
                      errorText: _showInvalid
                          ? l10n.savedTorrentsInvalidMagnet
                          : null,
                      errorMaxLines: 3,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: l10n.savedTorrentsPasteTooltip,
                        icon: const Icon(Icons.content_paste),
                        onPressed: _paste,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: AddSavedTorrentForm.nameFieldKey,
                    controller: _nameController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => canSave ? _save() : null,
                    decoration: InputDecoration(
                      labelText: l10n.savedTorrentsNameLabel,
                      helperText: l10n.savedTorrentsNameHelper,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: AddSavedTorrentForm.saveButtonKey,
                onPressed: canSave ? _save : null,
                child: Text(l10n.savedTorrentsSaveButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
