import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/torrent/magnet_link.dart';
import 'package:iris/shared/torrent/torrent_file.dart';
import 'package:iris/shared/torrent/torrent_file_picker.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/source_facts_line.dart';

typedef SaveTorrentCallback = Future<SaveTorrentResult> Function(String magnet);

/// Opens the "add torrent" form as a bottom sheet (compact) or dialog
/// (wider); [initialMagnet] starts it with a link, as pasted.
///
/// Resolves to the save result, or null when the user cancelled.
Future<SaveTorrentResult?> showAddSavedTorrentSheet({
  required BuildContext context,
  required SaveTorrentCallback onSave,
  String? initialMagnet,
  TorrentFilePicker pickFile = pickTorrentFile,
}) {
  return showAdaptiveSheet<SaveTorrentResult>(
    context: context,
    builder: (_) => AddSavedTorrentForm(
      onSave: onSave,
      initialMagnet: initialMagnet,
      pickFile: pickFile,
    ),
  );
}

/// A torrent comes as a magnet link or a `.torrent` file. Once there is
/// one, the input gives way to what it is (its name, files and size), so
/// the user sees what they are adding; clearing it brings the input back.
class AddSavedTorrentForm extends StatefulWidget {
  const AddSavedTorrentForm({
    required this.onSave,
    this.initialMagnet,
    this.pickFile = pickTorrentFile,
    super.key,
  });

  static const magnetFieldKey = Key('add_saved_torrent_magnet_field');
  static const fileButtonKey = Key('add_saved_torrent_file_button');
  static const draftKey = Key('add_saved_torrent_draft');
  static const clearDraftKey = Key('add_saved_torrent_clear_draft');
  static const saveButtonKey = Key('add_saved_torrent_save_button');

  final SaveTorrentCallback onSave;
  final String? initialMagnet;
  final TorrentFilePicker pickFile;

  @override
  State<AddSavedTorrentForm> createState() => _AddSavedTorrentFormState();
}

/// The torrent about to be added, and where it came from.
sealed class _Draft {
  const _Draft();

  String get magnet;
  String get name;
}

final class _LinkDraft extends _Draft {
  const _LinkDraft(this.link);

  final MagnetLink link;

  @override
  String get magnet => link.uri;

  @override
  String get name => link.displayName ?? link.infoHash;
}

final class _FileDraft extends _Draft {
  const _FileDraft(this.torrent);

  final TorrentFile torrent;

  @override
  String get magnet => torrent.magnet;

  @override
  String get name => torrent.name.isEmpty ? torrent.infoHash : torrent.name;
}

enum _Problem { invalidLink, notTorrent, saveFailed }

class _AddSavedTorrentFormState extends State<AddSavedTorrentForm> {
  final _magnetController = TextEditingController();
  _Draft? _draft;
  _Problem? _problem;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // A paste that is not a link starts an empty form, not one with an
    // error about text the user never typed here.
    final initial = MagnetLink.tryParse(widget.initialMagnet ?? '');
    if (initial != null) _draft = _LinkDraft(initial);
    _magnetController.addListener(_onMagnetChanged);
  }

  @override
  void dispose() {
    _magnetController.dispose();
    super.dispose();
  }

  void _onMagnetChanged() {
    final link = MagnetLink.tryParse(_magnetController.text);
    if (link != null) {
      setState(() {
        _draft = _LinkDraft(link);
        _problem = null;
      });
    } else if (_problem == _Problem.invalidLink) {
      setState(() => _problem = null);
    }
  }

  /// Says the text is not a link only when the user is done with it.
  void _checkLink() {
    if (_draft != null || _magnetController.text.trim().isEmpty) return;
    setState(() => _problem = _Problem.invalidLink);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (!mounted || text == null || text.isEmpty) return;
    _magnetController.text = text;
    _checkLink();
  }

  Future<void> _chooseFile() async {
    final bytes = await widget.pickFile();
    if (!mounted || bytes == null) return;
    final torrent = TorrentFile.tryParse(bytes);
    setState(() {
      _draft = torrent == null ? null : _FileDraft(torrent);
      _problem = torrent == null ? _Problem.notTorrent : null;
    });
  }

  void _clear() {
    _magnetController.clear();
    setState(() {
      _draft = null;
      _problem = null;
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (_saving || draft == null) return;
    final route = ModalRoute.of(context);
    setState(() {
      _saving = true;
      _problem = null;
    });
    final SaveTorrentResult result;
    try {
      result = await widget.onSave(draft.magnet);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Unable to save a torrent.',
        name: 'iris.saved_torrents.form',
        error: error.runtimeType,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _problem = _Problem.saveFailed;
      });
      return;
    }
    if (!mounted) return;
    if (route?.isCurrent == false) {
      setState(() => _saving = false);
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final draft = _draft;
    final compact = WindowSizeClass.of(context).isCompact;
    final saveButton = FilledButton(
      key: AddSavedTorrentForm.saveButtonKey,
      onPressed: draft != null && !_saving ? _save : null,
      child: Text(l10n.savedTorrentsAddConfirm),
    );

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
          Text(
            l10n.savedTorrentsAddTitle,
            style: theme.textTheme.titleLarge?.copyWith(wordSpacing: -3.6),
          ),
          const SizedBox(height: 18),
          Flexible(
            child: SingleChildScrollView(
              // The same place shows the torrent instead of the input.
              child: _AnimatedSizeIfEnabled(
                duration: motionDuration(
                  context,
                  const Duration(milliseconds: 200),
                ),
                alignment: AlignmentDirectional.topStart,
                child: DitherSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: draft == null
                      ? KeyedSubtree(
                          key: const ValueKey('input'),
                          child: _input(l10n, theme),
                        )
                      : _DraftCard(
                          key: ValueKey(draft.magnet),
                          draft: draft,
                          onClear: _clear,
                        ),
                ),
              ),
            ),
          ),
          if (_problem == _Problem.saveFailed)
            _problemNotice(l10n.savedTorrentsSaveFailed, theme),
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
              SizedBox(width: compact ? 12 : 8),
              if (compact) Expanded(child: saveButton) else saveButton,
            ],
          ),
        ],
      ),
    );
  }

  Widget _input(AppLocalizations l10n, ThemeData theme) {
    final scheme = theme.colorScheme;
    final rule = DetailLayout.ruleColor(scheme);
    final sans = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: AddSavedTorrentForm.magnetFieldKey,
          controller: _magnetController,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _checkLink(),
          onTapOutside: (_) => _checkLink(),
          style: sans,
          decoration: InputDecoration(
            labelText: l10n.savedTorrentsMagnetLabel,
            labelStyle: sans?.copyWith(color: scheme.onSurfaceVariant),
            hintText: 'magnet:?xt=urn:btih:…',
            errorText: _problem == _Problem.invalidLink
                ? l10n.savedTorrentsInvalidMagnet
                : null,
            errorStyle: theme.textTheme.bodySmall?.copyWith(
              fontFamily: DetailLayout.sansFont,
              color: scheme.error,
            ),
            errorMaxLines: 3,
            suffixIcon: IconButton(
              tooltip: l10n.savedTorrentsPasteTooltip,
              icon: const PixelIcon(PixelGlyph.paste, size: 18),
              onPressed: _paste,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(height: 1, thickness: 1, color: rule)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.savedTorrentsOr,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: DetailLayout.sansFont,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: Divider(height: 1, thickness: 1, color: rule)),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: AddSavedTorrentForm.fileButtonKey,
          onPressed: _chooseFile,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            backgroundColor: scheme.surfaceContainerLow,
            side: BorderSide(color: rule),
          ),
          icon: const PixelIcon(PixelGlyph.file, size: 16),
          label: Text(
            l10n.savedTorrentsChooseFile,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: DetailLayout.sansFont,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
        ),
        _buildProblemNotice(context, l10n, theme),
      ],
    );
  }

  Widget _buildProblemNotice(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final duration = motionDuration(context, const Duration(milliseconds: 160));
    final notice = _problem == _Problem.notTorrent
        ? KeyedSubtree(
            key: const ValueKey('not_torrent_error'),
            child: _problemNotice(l10n.savedTorrentsNotTorrentFile, theme),
          )
        : const SizedBox.shrink(key: ValueKey('no_problem'));
    if (duration == Duration.zero) return notice;
    return _AnimatedSizeIfEnabled(
      duration: duration,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        child: notice,
      ),
    );
  }

  Widget _problemNotice(String message, ThemeData theme) => SizedBox(
    width: double.infinity,
    child: Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: DetailLayout.sansFont,
            color: theme.colorScheme.error,
          ),
        ),
      ),
    ),
  );
}

class _AnimatedSizeIfEnabled extends StatelessWidget {
  const _AnimatedSizeIfEnabled({
    required this.duration,
    required this.alignment,
    required this.child,
  });

  final Duration duration;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: alignment,
      child: child,
    );
  }
}

/// The torrent about to be added: its name and what is known about it.
class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft, required this.onClear, super.key});

  final _Draft draft;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final facts = switch (draft) {
      _FileDraft(:final torrent) => [
        l10n.savedTorrentsFileCount(torrent.fileCount),
        formatByteSize(l10n, torrent.size),
        l10n.savedTorrentsFromFile,
      ],
      _LinkDraft(:final link) => [
        if (link.size case final size?) formatByteSize(l10n, size),
        l10n.savedTorrentsFromLink,
      ],
    };
    return DecoratedBox(
      key: AddSavedTorrentForm.draftKey,
      decoration: DetailLayout.cardDecoration(theme.colorScheme),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SourceFactsLine(watched: false, facts: facts.join(' · ')),
                ],
              ),
            ),
            IconButton(
              key: AddSavedTorrentForm.clearDraftKey,
              tooltip: l10n.savedTorrentsClearDraft,
              icon: const PixelIcon(PixelGlyph.close, size: 16),
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}
