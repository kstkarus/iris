import 'dart:async';

import 'package:libtorrent_flutter/libtorrent_flutter.dart';

/// The engine gave up on a torrent before its metadata arrived.
class TorrentMetadataFailedException implements Exception {
  const TorrentMetadataFailedException(this.message);

  final String message;

  @override
  String toString() => 'TorrentMetadataFailedException: $message';
}

/// Completes once [torrentId] has metadata.
///
/// Fails with [TorrentMetadataFailedException] as soon as the engine reports
/// an error for the torrent, or drops it after having listed it (removed by
/// another owner), and with [TimeoutException] after [timeout]. A torrent
/// that is not listed yet is still being added: the engine lists a new
/// torrent only on its next poll.
Future<void> waitForTorrentMetadata({
  required int torrentId,
  required Map<int, TorrentInfo> current,
  required Stream<Map<int, TorrentInfo>> updates,
  required Duration timeout,
}) async {
  var listed = false;
  bool hasMetadata(Map<int, TorrentInfo> torrents) {
    final torrent = torrents[torrentId];
    if (torrent == null) {
      if (listed) {
        throw const TorrentMetadataFailedException('The torrent was removed.');
      }
      return false;
    }
    listed = true;
    if (torrent.state == TorrentState.error) {
      final message = torrent.errorMsg.trim();
      throw TorrentMetadataFailedException(
        message.isEmpty ? 'The torrent failed.' : message,
      );
    }
    return torrent.hasMetadata;
  }

  if (hasMetadata(current)) return;
  await updates.firstWhere(hasMetadata).timeout(timeout);
}
