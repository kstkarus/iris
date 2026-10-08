import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/add_saved_torrent_sheet.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/saved_torrents_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// The user's own magnet links, independent from the anime catalog.
class SavedTorrentsPage extends StatelessWidget {
  const SavedTorrentsPage({
    required this.onWatch,
    required this.onDownload,
    super.key,
  });

  static const addButtonKey = Key('saved_torrents_add_button');

  final SavedTorrentWatchCallback onWatch;
  final ValueChanged<SavedTorrent> onDownload;

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(context);
    final margin = sizeClass.pageMargin;

    return Scaffold(
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): () =>
              _addFromClipboard(context),
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () =>
              _addFromClipboard(context),
        },
        child: Focus(
          autofocus: true,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                margin,
                sizeClass.pageTop,
                margin,
                0,
              ),
              child: MaxWidthBox(
                maxWidth: AdaptiveContentWidth.page,
                child: SavedTorrentsView(
                  addButtonKey: addButtonKey,
                  onAdd: () => _add(context),
                  onWatch: (torrent, {autoOpenFileIndex}) => _open(
                    context,
                    torrent,
                    (torrent) =>
                        onWatch(torrent, autoOpenFileIndex: autoOpenFileIndex),
                  ),
                  onDownload: (torrent) => _open(context, torrent, onDownload),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(
    BuildContext context,
    SavedTorrent torrent,
    ValueChanged<SavedTorrent> navigate,
  ) {
    context.read<SavedTorrentsCubit>().markOpened(torrent.infoHash);
    navigate(torrent);
  }

  Future<void> _addFromClipboard(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;
    await _add(context, initialMagnet: data?.text?.trim());
  }

  Future<void> _add(BuildContext context, {String? initialMagnet}) async {
    final cubit = context.read<SavedTorrentsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await showAddSavedTorrentSheet(
      context: context,
      onSave: cubit.add,
      initialMagnet: initialMagnet,
    );
    final message = switch (result) {
      SaveTorrentAdded() => l10n.savedTorrentsAdded,
      SaveTorrentDuplicate(:final existing) => l10n.savedTorrentsDuplicate(
        existing.title,
      ),
      SaveTorrentInvalidMagnet() || null => null,
    };
    if (message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
