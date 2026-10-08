import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';

import 'package:iris/shared/torrent/torrent_metadata_wait.dart';

void main() {
  late StreamController<Map<int, TorrentInfo>> updates;

  setUp(() => updates = StreamController<Map<int, TorrentInfo>>.broadcast());
  tearDown(() => updates.close());

  Future<void> wait({Map<int, TorrentInfo> current = const {}}) {
    return waitForTorrentMetadata(
      torrentId: 7,
      current: current,
      updates: updates.stream,
      timeout: const Duration(seconds: 90),
    );
  }

  test('completes at once when the metadata is already there', () async {
    await wait(current: {7: _torrent(hasMetadata: true)});
  });

  test('completes when the metadata arrives', () async {
    final waiting = wait();
    updates.add({7: _torrent()});
    updates.add({7: _torrent(hasMetadata: true)});
    await waiting;
  });

  test('waits for a torrent the engine has not listed yet', () async {
    var done = false;
    final waiting = wait().then((_) => done = true);
    updates.add(const {});
    await pumpEventQueue();
    expect(done, isFalse);

    updates.add({7: _torrent(hasMetadata: true)});
    await waiting;
  });

  test('fails at once on an engine error', () async {
    final waiting = wait();
    updates.add({7: _torrent(state: TorrentState.error, errorMsg: 'boom')});
    await expectLater(
      waiting,
      throwsA(
        isA<TorrentMetadataFailedException>().having(
          (error) => error.message,
          'message',
          'boom',
        ),
      ),
    );
  });

  test('fails on an error that is already reported', () async {
    await expectLater(
      wait(current: {7: _torrent(state: TorrentState.error)}),
      throwsA(isA<TorrentMetadataFailedException>()),
    );
  });

  test('fails when a listed torrent is removed', () async {
    final waiting = wait(current: {7: _torrent()});
    updates.add(const {});
    await expectLater(waiting, throwsA(isA<TorrentMetadataFailedException>()));
  });

  test('times out without metadata', () async {
    await expectLater(
      waitForTorrentMetadata(
        torrentId: 7,
        current: const {},
        updates: updates.stream,
        timeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}

TorrentInfo _torrent({
  bool hasMetadata = false,
  TorrentState state = TorrentState.downloadingMetadata,
  String errorMsg = '',
}) {
  return TorrentInfo(
    id: 7,
    name: 'torrent',
    savePath: '',
    errorMsg: errorMsg,
    state: state,
    progress: 0,
    downloadRate: 0,
    uploadRate: 0,
    totalDone: 0,
    totalWanted: 0,
    totalUploaded: 0,
    numPeers: 0,
    numSeeds: 0,
    isPaused: false,
    isFinished: false,
    hasMetadata: hasMetadata,
    queuePosition: 0,
  );
}
