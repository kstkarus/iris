import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/saved_torrents/data/models/saved_torrent_model.dart';
import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/shared/storage/json_list_preference.dart';
import 'package:iris/shared/torrent/magnet_link.dart';

class SharedPreferencesSavedTorrentsRepository
    implements SavedTorrentsRepository {
  SharedPreferencesSavedTorrentsRepository(
    SharedPreferences preferences, {
    DateTime Function() now = DateTime.now,
  }) : _storage = JsonListPreference(
         preferences,
         'saved_torrents.items',
         decode: SavedTorrentModel.fromJson,
         encode: SavedTorrentModel.toJson,
         logName: 'iris.saved_torrents.repository',
         corruptedMessage:
             'Saved torrents storage is corrupted; starting with an empty list.',
       ),
       _now = now;

  final JsonListPreference<SavedTorrent> _storage;
  final DateTime Function() _now;
  final StreamController<List<SavedTorrent>> _changes =
      StreamController<List<SavedTorrent>>.broadcast();

  @override
  Stream<List<SavedTorrent>> watchTorrents(String animeId) async* {
    yield _of(animeId, _read());
    yield* _changes.stream.map((torrents) => _of(animeId, torrents));
  }

  @override
  Future<SaveTorrentResult> add({
    required String animeId,
    required String magnet,
  }) async {
    final link = MagnetLink.tryParse(magnet);
    if (link == null) return const SaveTorrentInvalidMagnet();

    final torrents = _read();
    for (final existing in torrents) {
      if (_same(existing, animeId, link.infoHash)) {
        return SaveTorrentDuplicate(existing);
      }
    }

    final torrent = SavedTorrent(
      animeId: animeId,
      infoHash: link.infoHash,
      magnet: link.uri,
      title: link.displayName ?? link.infoHash,
      addedAt: _now(),
    );
    await _write([...torrents, torrent]);
    return SaveTorrentAdded(torrent);
  }

  @override
  Future<void> rename(SavedTorrent torrent, String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return Future<void>.value();
    return _update(torrent, (saved) => saved.copyWith(title: trimmed));
  }

  @override
  Future<void> markOpened(SavedTorrent torrent) {
    return _update(torrent, (saved) => saved.copyWith(lastOpenedAt: _now()));
  }

  @override
  Future<void> delete(SavedTorrent torrent) async {
    final torrents = _read();
    final remaining = [
      for (final saved in torrents)
        if (!_same(saved, torrent.animeId, torrent.infoHash)) saved,
    ];
    if (remaining.length == torrents.length) return;
    await _write(remaining);
  }

  @override
  Future<void> restore(SavedTorrent torrent) async {
    final torrents = _read();
    if (torrents.any(
      (saved) => _same(saved, torrent.animeId, torrent.infoHash),
    )) {
      return;
    }
    await _write([...torrents, torrent]);
  }

  Future<void> close() => _changes.close();

  Future<void> _update(
    SavedTorrent torrent,
    SavedTorrent Function(SavedTorrent saved) change,
  ) async {
    final torrents = _read();
    final index = torrents.indexWhere(
      (saved) => _same(saved, torrent.animeId, torrent.infoHash),
    );
    if (index < 0) return;
    torrents[index] = change(torrents[index]);
    await _write(torrents);
  }

  static bool _same(SavedTorrent torrent, String animeId, String infoHash) =>
      torrent.animeId == animeId && torrent.infoHash == infoHash;

  List<SavedTorrent> _read() {
    // Both spellings of one info-hash may have been saved before they were
    // unified; the one added first stands.
    final seen = <(String, String)>{};
    return [
      for (final torrent in _storage.read())
        if (seen.add((torrent.animeId, torrent.infoHash))) torrent,
    ];
  }

  Future<void> _write(List<SavedTorrent> torrents) async {
    await _storage.write(torrents);
    if (!_changes.isClosed) _changes.add(torrents);
  }

  List<SavedTorrent> _of(String animeId, List<SavedTorrent> torrents) {
    return _sorted([
      for (final torrent in torrents)
        if (torrent.animeId == animeId) torrent,
    ]);
  }

  List<SavedTorrent> _sorted(List<SavedTorrent> torrents) {
    return List<SavedTorrent>.unmodifiable(
      [...torrents]..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt)),
    );
  }
}
