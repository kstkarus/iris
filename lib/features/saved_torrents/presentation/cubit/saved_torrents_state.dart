import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';

class SavedTorrentsState {
  const SavedTorrentsState({
    this.isLoading = true,
    this.torrents = const [],
    this.highlightedInfoHash,
  });

  final bool isLoading;

  /// Most recently used first.
  final List<SavedTorrent> torrents;

  /// Briefly highlighted entry: just added, or the existing duplicate.
  final String? highlightedInfoHash;

  SavedTorrentsState copyWith({
    bool? isLoading,
    List<SavedTorrent>? torrents,
    String? highlightedInfoHash,
    bool clearHighlight = false,
  }) {
    return SavedTorrentsState(
      isLoading: isLoading ?? this.isLoading,
      torrents: torrents ?? this.torrents,
      highlightedInfoHash: clearHighlight
          ? null
          : highlightedInfoHash ?? this.highlightedInfoHash,
    );
  }
}
