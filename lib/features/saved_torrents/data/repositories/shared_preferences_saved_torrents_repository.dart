import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/saved_torrents/data/models/saved_torrent_model.dart';
import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/shared/torrent/magnet_link.dart';

class SharedPreferencesSavedTorrentsRepository
    implements SavedTorrentsRepository {
  SharedPreferencesSavedTorrentsRepository(
    this._preferences, {
    DateTime Function() now = DateTime.now,
  }) : _now = now;

  static const _storageKey = 'saved_torrents.items';

  final SharedPreferences _preferences;
  final DateTime Function() _now;
  final StreamController<List<SavedTorrent>> _changes =
      StreamController<List<SavedTorrent>>.broadcast();

  @override
  Stream<List<SavedTorrent>> watchTorrents() async* {
    yield _sorted(_read());
    yield* _changes.stream;
  }

  @override
  Future<SaveTorrentResult> add({required String magnet, String? title}) async {
    final link = MagnetLink.tryParse(magnet);
    if (link == null) return const SaveTorrentInvalidMagnet();

    final torrents = _read();
    for (final existing in torrents) {
      if (existing.infoHash == link.infoHash) {
        return SaveTorrentDuplicate(existing);
      }
    }

    final trimmedTitle = title?.trim() ?? '';
    final torrent = SavedTorrent(
      infoHash: link.infoHash,
      magnet: link.uri,
      title: trimmedTitle.isNotEmpty
          ? trimmedTitle
          : link.displayName ?? link.infoHash,
      addedAt: _now(),
    );
    await _write([...torrents, torrent]);
    return SaveTorrentAdded(torrent);
  }

  @override
  Future<void> rename({required String infoHash, required String title}) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return Future<void>.value();
    return _update(infoHash, (torrent) => torrent.copyWith(title: trimmed));
  }

  @override
  Future<void> markOpened({required String infoHash}) {
    return _update(
      infoHash,
      (torrent) => torrent.copyWith(lastOpenedAt: _now()),
    );
  }

  @override
  Future<void> delete({required String infoHash}) async {
    final torrents = _read();
    final remaining = torrents
        .where((torrent) => torrent.infoHash != infoHash)
        .toList();
    if (remaining.length == torrents.length) return;
    await _write(remaining);
  }

  @override
  Future<void> restore(SavedTorrent torrent) async {
    final torrents = _read();
    if (torrents.any((saved) => saved.infoHash == torrent.infoHash)) return;
    await _write([...torrents, torrent]);
  }

  Future<void> close() => _changes.close();

  Future<void> _update(
    String infoHash,
    SavedTorrent Function(SavedTorrent torrent) change,
  ) async {
    final torrents = _read();
    final index = torrents.indexWhere(
      (torrent) => torrent.infoHash == infoHash,
    );
    if (index < 0) return;
    torrents[index] = change(torrents[index]);
    await _write(torrents);
  }

  List<SavedTorrent> _read() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      // Both spellings of one info-hash may have been saved before they were
      // unified; the one added first stands.
      final seen = <String>{};
      return [
        for (final entry in decoded)
          if (SavedTorrentModel.fromJson(entry) case final torrent?
              when seen.add(torrent.infoHash))
            torrent,
      ];
    } on FormatException catch (error, stackTrace) {
      developer.log(
        'Saved torrents storage is corrupted; starting with an empty list.',
        name: 'iris.saved_torrents.repository',
        error: error,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<void> _write(List<SavedTorrent> torrents) async {
    await _preferences.setString(
      _storageKey,
      jsonEncode([
        for (final torrent in torrents) SavedTorrentModel.toJson(torrent),
      ]),
    );
    if (!_changes.isClosed) _changes.add(_sorted(torrents));
  }

  List<SavedTorrent> _sorted(List<SavedTorrent> torrents) {
    return List<SavedTorrent>.unmodifiable(
      [...torrents]..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt)),
    );
  }
}
