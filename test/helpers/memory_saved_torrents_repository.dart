import 'dart:async';

import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/shared/torrent/magnet_link.dart';

/// The user's own torrents in memory, for pages that show them.
class MemorySavedTorrentsRepository implements SavedTorrentsRepository {
  final _torrents = <SavedTorrent>[];
  final _changes = StreamController<void>.broadcast();

  List<SavedTorrent> _of(String animeId) => [
    for (final torrent in _torrents)
      if (torrent.animeId == animeId) torrent,
  ];

  @override
  Stream<List<SavedTorrent>> watchTorrents(String animeId) async* {
    yield _of(animeId);
    yield* _changes.stream.map((_) => _of(animeId));
  }

  @override
  Future<SaveTorrentResult> add({
    required String animeId,
    required String magnet,
  }) async {
    final link = MagnetLink.tryParse(magnet);
    if (link == null) return const SaveTorrentInvalidMagnet();
    for (final torrent in _of(animeId)) {
      if (torrent.infoHash == link.infoHash) {
        return SaveTorrentDuplicate(torrent);
      }
    }
    final torrent = SavedTorrent(
      animeId: animeId,
      infoHash: link.infoHash,
      magnet: link.uri,
      title: link.displayName ?? link.infoHash,
      addedAt: DateTime.utc(2026, 10, 12),
    );
    _torrents.insert(0, torrent);
    _changes.add(null);
    return SaveTorrentAdded(torrent);
  }

  @override
  Future<void> rename(SavedTorrent torrent, String title) async =>
      _replace(torrent, torrent.copyWith(title: title));

  @override
  Future<void> markOpened(SavedTorrent torrent) async =>
      _replace(torrent, torrent.copyWith(lastOpenedAt: DateTime.utc(2026)));

  @override
  Future<void> delete(SavedTorrent torrent) async {
    _torrents.remove(torrent);
    _changes.add(null);
  }

  @override
  Future<void> restore(SavedTorrent torrent) async {
    if (_torrents.contains(torrent)) return;
    _torrents.add(torrent);
    _changes.add(null);
  }

  void _replace(SavedTorrent old, SavedTorrent updated) {
    final index = _torrents.indexOf(old);
    if (index < 0) return;
    _torrents[index] = updated;
    _changes.add(null);
  }
}
