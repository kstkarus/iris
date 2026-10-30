import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:iris/features/downloads/data/adapters/online_episode_downloader.dart';
import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/online/online_source_link.dart';

import '../../../../helpers/fake_http_adapter.dart';

const _link = OnlineSourceLink(
  provider: 'anilibria',
  releaseId: '9542',
  animeId: '52991',
);

const _release = OnlineRelease(
  provider: OnlineProvider.anilibria,
  id: '9542',
  dub: 'AniLibria',
  episodes: [
    OnlineEpisode(id: 'e1', number: 1, title: '«Конец приключений»'),
    OnlineEpisode(id: 'e2', number: 2),
  ],
);

OnlineStream _hls(String url, {int quality = 720}) =>
    OnlineStream(url: url, quality: quality, format: OnlineStreamFormat.hls);

/// A media playlist of [count] segments of 6 s, named `s<n>.ts`.
String _playlist(int count) => [
  '#EXTM3U',
  for (var n = 1; n <= count; n++) ...['#EXTINF:6.0,', 's$n.ts'],
  '#EXT-X-ENDLIST',
].join('\n');

void main() {
  late Directory directory;
  late _FakeOnlineSources sources;
  late List<Duration> delays;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('iris_online_download_');
    sources = _FakeOnlineSources();
    delays = [];
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  OnlineEpisodeDownloader downloader(
    FutureOr<FakeReply> Function(RequestOptions options) respond,
  ) {
    return OnlineEpisodeDownloader(
      repository: sources,
      dio: fakeDio(respond),
      delay: (delay) async => delays.add(delay),
    );
  }

  OnlineDownloadTask start(OnlineEpisodeDownloader downloader) =>
      downloader.start(link: _link, fileIndex: 2, directory: directory);

  bool stateLeft() =>
      File(path.join(directory.path, 'online_download.json')).existsSync();

  Future<void> pauseAfterFirstPiece({String? playlist}) async {
    sources.streams = [_hls('https://cdn.test/e2/720.m3u8')];
    final secondAsked = Completer<void>();
    final task = start(
      downloader((options) {
        final name = options.uri.pathSegments.last;
        if (name.endsWith('.m3u8')) {
          return FakeReply.text(200, playlist ?? _playlist(2));
        }
        if (name == 's2.ts') {
          secondAsked.complete();
          return Completer<FakeReply>().future;
        }
        return FakeReply.text(200, '[$name]');
      }),
    );
    await secondAsked.future;
    await task.cancel();
    expect(await task.done, isNull);
  }

  test('offers the episodes as files, by number, of no known size', () async {
    sources.streams = [
      _hls('https://cdn.test/e1/1080.m3u8', quality: 1080),
      const OnlineStream(
        url: 'https://cdn.test/e1/1080.mpd',
        quality: 1080,
        format: OnlineStreamFormat.dash,
      ),
      const OnlineStream(
        url: 'https://cdn.test/e1/2160.mpd',
        quality: 2160,
        format: OnlineStreamFormat.dash,
      ),
      _hls('https://cdn.test/e1/720.m3u8'),
    ];
    final (:files, :qualities) = await downloader(
      (_) => const FakeReply(404),
    ).episodes(_link);

    // Only what can be loaded, as the first episode has it.
    expect(sources.resolved, ['e1']);
    expect(qualities, [1080, 720]);
    expect(files, const [
      DownloadableFile(
        index: 1,
        name: '01 «Конец приключений»',
        relativePath: '',
        size: 0,
      ),
      DownloadableFile(index: 2, name: '02', relativePath: '', size: 0),
    ]);
  });

  test('an episode that gives no streams yet offers no qualities', () async {
    sources.failResolve = true;

    final (:files, :qualities) = await downloader(
      (_) => const FakeReply(404),
    ).episodes(_link);

    expect(files, hasLength(2));
    expect(qualities, isEmpty);
  });

  test('saves an external subtitle beside the downloaded video', () async {
    sources.streams = [
      const OnlineStream(
        url: 'https://cdn.test/e2/720.m3u8',
        quality: 720,
        format: OnlineStreamFormat.hls,
        subtitleUrl: 'https://cdn.test/e2/full.vtt',
      ),
    ];
    final task = start(
      downloader((options) {
        final name = options.uri.pathSegments.last;
        if (name.endsWith('.vtt')) {
          return const FakeReply.text(200, 'WEBVTT\n\n');
        }
        if (name.endsWith('.m3u8')) return FakeReply.text(200, _playlist(1));
        return const FakeReply.text(200, 'video');
      }),
    );
    final video = await task.done;
    expect(path.basename(video!.path), 'episode.ts');
    expect(
      await File(path.join(directory.path, 'episode.vtt')).readAsString(),
      'WEBVTT\n\n',
    );
  });

  test('loads the quality asked for, or the closest below it', () async {
    sources.streams = [
      _hls('https://cdn.test/e2/1080.m3u8', quality: 1080),
      _hls('https://cdn.test/e2/720.m3u8'),
      _hls('https://cdn.test/e2/480.m3u8', quality: 480),
    ];
    final asked = <String>[];
    final task = downloader((options) {
      final name = options.uri.pathSegments.last;
      asked.add(name);
      return name.endsWith('.m3u8')
          ? FakeReply.text(200, _playlist(1))
          : FakeReply.text(200, '[$name]');
    }).start(link: _link, fileIndex: 2, directory: directory, maxQuality: 900);

    await task.done;

    expect(asked.first, '720.m3u8');
  });

  test(
    'reports the HLS master variant height selected below the provider height',
    () async {
      sources.streams = [
        _hls('https://cdn.test/e2/master.m3u8', quality: 1080),
      ];
      final task =
          downloader((options) {
            if (options.uri.path.endsWith('master.m3u8')) {
              return FakeReply.text(200, '''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=2500000,RESOLUTION=1280x720
720/index.m3u8
''');
            }
            return options.uri.path.endsWith('.m3u8')
                ? FakeReply.text(200, _playlist(1))
                : FakeReply.text(200, '[$options.uri]');
          }).start(
            link: _link,
            fileIndex: 2,
            directory: directory,
            maxQuality: 1080,
          );
      final updates = <OnlineDownloadProgress>[];
      task.progress.listen(updates.add);

      await task.done;

      expect(updates, isNotEmpty);
      expect(updates.map((update) => update.videoHeight), everyElement(720));
    },
  );

  test(
    'glues an HLS episode into one file and reports how far it is',
    () async {
      sources.streams = [
        _hls('https://cdn.test/e2/1080.m3u8', quality: 1080),
        _hls('https://cdn.test/e2/720.m3u8'),
      ];
      final task = start(
        downloader((options) {
          final name = options.uri.pathSegments.last;
          return name == '1080.m3u8'
              ? FakeReply.text(200, _playlist(3))
              : FakeReply.text(200, '[$name]');
        }),
      );
      final updates = <OnlineDownloadProgress>[];
      task.progress.listen(updates.add);

      final file = await task.done;

      expect(sources.resolved, ['e2']);
      expect(path.basename(file!.path), 'episode.ts');
      expect(await file.readAsString(), '[s1.ts][s2.ts][s3.ts]');
      expect(stateLeft(), isFalse);
      expect(updates.last.downloadedBytes, 21);
      expect(updates.last.totalBytes, 21);
      // After one of three equal segments, the whole is three times as big.
      expect(updates[1].downloadedBytes, 7);
      expect(updates[1].totalBytes, 21);
      expect(updates.map((update) => update.videoHeight), everyElement(1080));
    },
  );

  test('a cancelled episode picks up from the next segment, in the quality '
      'it began in', () async {
    sources.streams = [_hls('https://cdn.test/e2/720.m3u8')];
    final secondAsked = Completer<void>();
    final first = start(
      downloader((options) async {
        final name = options.uri.pathSegments.last;
        if (name == '720.m3u8') return FakeReply.text(200, _playlist(3));
        if (name == 's2.ts') {
          secondAsked.complete();
          await Completer<void>().future;
        }
        return FakeReply.text(200, '[$name]');
      }),
    );
    await secondAsked.future;
    await first.cancel();
    expect(await first.done, isNull);
    expect(stateLeft(), isTrue);

    // A better quality has come up since; the episode stays in its own.
    sources.streams = [
      _hls('https://cdn.test/e2/1080.m3u8', quality: 1080),
      _hls('https://cdn.test/e2/720.m3u8'),
    ];
    final asked = <String>[];
    final second = start(
      downloader((options) {
        final name = options.uri.pathSegments.last;
        asked.add(name);
        return name.endsWith('.m3u8')
            ? FakeReply.text(200, _playlist(3))
            : FakeReply.text(200, '[$name]');
      }),
    );

    final file = await second.done;
    expect(asked, ['720.m3u8', 's2.ts', 's3.ts']);
    expect(await file!.readAsString(), '[s1.ts][s2.ts][s3.ts]');
  });

  test('a refused segment renews the link and goes on where it was', () async {
    var resolves = 0;
    sources.onResolve = () => [_hls('https://cdn.test/${++resolves}/720.m3u8')];
    final asked = <String>[];
    final task = start(
      downloader((options) {
        final [link, name] = options.uri.pathSegments;
        asked.add('$link/$name');
        if (name == '720.m3u8') return FakeReply.text(200, _playlist(3));
        if (link == '1' && name == 's2.ts') return const FakeReply(403);
        return FakeReply.text(200, '[$link/$name]');
      }),
    );

    final file = await task.done;

    expect(resolves, 2);
    expect(asked, [
      '1/720.m3u8',
      '1/s1.ts',
      '1/s2.ts',
      '2/720.m3u8',
      '2/s2.ts',
      '2/s3.ts',
    ]);
    expect(await file!.readAsString(), '[1/s1.ts][2/s2.ts][2/s3.ts]');
    expect(delays, isEmpty, reason: 'a refusal is not tried again as it is');
  });

  test('a network that is gone a while is waited for', () async {
    sources
      ..streams = [_hls('https://cdn.test/e2/720.m3u8')]
      ..offlineReleases = 2
      ..offlineResolves = 1;
    final task = start(
      downloader((options) {
        final name = options.uri.pathSegments.last;
        if (name == '720.m3u8') return FakeReply.text(200, _playlist(1));
        return FakeReply.text(200, '[$name]');
      }),
    );

    final file = await task.done;

    expect(await file!.readAsString(), '[s1.ts]');
    expect(delays, const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 2),
    ]);
  });

  test('a network gone for long fails the download, to be resumed', () async {
    sources
      ..streams = [_hls('https://cdn.test/e2/720.m3u8')]
      ..offlineReleases = 100;
    final task = start(downloader((_) => const FakeReply(200)));

    await expectLater(task.done, throwsA(isA<OnlineDownloadException>()));
    expect(delays, hasLength(8));
  });

  test('a pause during a wait for the network is not held up by it', () async {
    sources
      ..streams = [_hls('https://cdn.test/e2/720.m3u8')]
      ..offlineReleases = 100;
    final waiting = Completer<void>();
    final task = OnlineEpisodeDownloader(
      repository: sources,
      dio: fakeDio((_) => const FakeReply(200)),
      // A wait that would last until the end of the test.
      delay: (_) {
        if (!waiting.isCompleted) waiting.complete();
        return Completer<void>().future;
      },
    ).start(link: _link, fileIndex: 2, directory: directory);
    await waiting.future;

    await task.cancel();

    expect(await task.done, isNull);
  });

  for (final waitingForRelease in [true, false]) {
    for (final failsLate in [false, true]) {
      final request = waitingForRelease ? 'release' : 'stream list';
      final reply = failsLate ? 'failure' : 'success';
      test('a pause drops a pending $request and its late $reply', () async {
        final requested = Completer<void>();
        final answer = Completer<void>();
        sources.onRelease = () async {
          if (waitingForRelease) {
            requested.complete();
            await answer.future;
          }
          return _release;
        };
        sources.onResolve = () async {
          if (!waitingForRelease) {
            requested.complete();
            await answer.future;
          }
          return [_hls('https://cdn.test/e2/720.m3u8')];
        };
        final mediaRequests = <Uri>[];
        final task = start(
          downloader((options) {
            mediaRequests.add(options.uri);
            return const FakeReply(404);
          }),
        );
        await requested.future;

        var stopped = false;
        final stopping = task.cancel().then((_) => stopped = true);
        await pumpEventQueue();
        try {
          expect(
            stopped,
            isTrue,
            reason: 'pause must finish before the provider answers',
          );
          expect(await task.done, isNull);
          // Delete can remove the folder as soon as cancellation finishes.
          await directory.delete(recursive: true);
        } finally {
          if (failsLate) {
            answer.completeError(const NetworkRequestException('offline'));
          } else {
            answer.complete();
          }
          await stopping;
        }
        await pumpEventQueue();

        expect(mediaRequests, isEmpty);
        expect(await directory.exists(), isFalse);
      });
    }
  }

  test('an episode whose segment list changed starts over', () async {
    var resolves = 0;
    sources.onResolve = () => [_hls('https://cdn.test/${++resolves}/720.m3u8')];
    final task = start(
      downloader((options) {
        final [link, name] = options.uri.pathSegments;
        if (name == '720.m3u8') {
          return FakeReply.text(200, _playlist(link == '1' ? 3 : 2));
        }
        if (link == '1' && name == 's2.ts') return const FakeReply(410);
        return FakeReply.text(200, '[$link/$name]');
      }),
    );

    final file = await task.done;

    expect(await file!.readAsString(), '[2/s1.ts][2/s2.ts]');
  });

  for (final changed in ['names', 'order', 'durations', 'init']) {
    test(
      'HLS starts over when $changed change with the same piece count',
      () async {
        await pauseAfterFirstPiece(
          playlist: changed == 'init'
              ? '#EXTM3U\n#EXT-X-MAP:URI="old-init.mp4"\n#EXTINF:6,\ns2.ts\n#EXT-X-ENDLIST'
              : null,
        );
        final playlist = switch (changed) {
          'names' => _playlist(
            2,
          ).replaceAll('s1.ts', 'new1.ts').replaceAll('s2.ts', 'new2.ts'),
          'order' =>
            '#EXTM3U\n#EXTINF:6,\ns2.ts\n#EXTINF:6,\ns1.ts\n#EXT-X-ENDLIST',
          'durations' => _playlist(2).replaceAll('6.0', '8.0'),
          _ =>
            '#EXTM3U\n#EXT-X-MAP:URI="init.mp4"\n#EXTINF:6,\ns2.ts\n#EXT-X-ENDLIST',
        };
        final asked = <String>[];
        final task = start(
          downloader((options) {
            final name = options.uri.pathSegments.last;
            asked.add(name);
            return name.endsWith('.m3u8')
                ? FakeReply.text(200, playlist)
                : FakeReply.text(200, '[new:$name]');
          }),
        );
        final file = (await task.done)!;
        final pieces = switch (changed) {
          'names' => ['new1.ts', 'new2.ts'],
          'order' => ['s2.ts', 's1.ts'],
          'init' => ['init.mp4', 's2.ts'],
          _ => ['s1.ts', 's2.ts'],
        };
        expect(asked, ['720.m3u8', ...pieces]);
        expect(
          await file.readAsString(),
          pieces.map((name) => '[new:$name]').join(),
        );
      },
    );
  }

  for (final legacy in [false, true]) {
    test(
      legacy
          ? 'HLS restarts when an old checkpoint has no playlist identity'
          : 'HLS restarts instead of padding a file shorter than its checkpoint',
      () async {
        await pauseAfterFirstPiece();
        if (legacy) {
          final state = File(path.join(directory.path, 'online_download.json'));
          final json =
              jsonDecode(await state.readAsString()) as Map<String, dynamic>;
          json.remove('playlistHash');
          await state.writeAsString(jsonEncode(json));
        } else {
          await File(
            path.join(directory.path, 'episode.ts'),
          ).writeAsString('[s');
        }
        final asked = <String>[];
        final task = start(
          downloader((options) {
            final name = options.uri.pathSegments.last;
            asked.add(name);
            return name.endsWith('.m3u8')
                ? FakeReply.text(200, _playlist(2))
                : FakeReply.text(200, '[$name]');
          }),
        );

        expect(await (await task.done)!.readAsString(), '[s1.ts][s2.ts]');
        expect(asked, ['720.m3u8', 's1.ts', 's2.ts']);
      },
    );
  }

  test('a server error is tried again after a growing wait', () async {
    sources.streams = [_hls('https://cdn.test/e2/720.m3u8')];
    var failures = 0;
    final task = start(
      downloader((options) {
        final name = options.uri.pathSegments.last;
        if (name == '720.m3u8') return FakeReply.text(200, _playlist(2));
        if (name == 's2.ts' && failures++ < 2) return const FakeReply(502);
        return FakeReply.text(200, '[$name]');
      }),
    );

    final file = await task.done;

    expect(await file!.readAsString(), '[s1.ts][s2.ts]');
    expect(delays, const [Duration(seconds: 1), Duration(seconds: 2)]);
  });

  test(
    'a server that never answers fails the download, to be resumed',
    () async {
      sources.streams = [_hls('https://cdn.test/e2/720.m3u8')];
      final task = start(
        downloader((options) {
          final name = options.uri.pathSegments.last;
          if (name == '720.m3u8') return FakeReply.text(200, _playlist(2));
          if (name == 's2.ts') return const FakeReply(503);
          return FakeReply.text(200, '[$name]');
        }),
      );

      await expectLater(
        task.done,
        throwsA(
          isA<OnlineDownloadException>().having(
            (error) => downloadFailureFrom(error.message),
            'failure',
            DownloadFailure.connectionLost,
          ),
        ),
      );
      expect(stateLeft(), isTrue, reason: 'a retry goes on from s2');
    },
  );

  test('an episode only in DASH cannot be downloaded', () async {
    sources.streams = const [
      OnlineStream(
        url: 'https://cdn.test/e2/1080.mpd',
        quality: 1080,
        format: OnlineStreamFormat.dash,
      ),
    ];
    final task = start(downloader((_) => const FakeReply(404)));

    await expectLater(
      task.done,
      throwsA(
        isA<OnlineDownloadException>().having(
          (error) => downloadFailureFrom(error.message),
          'failure',
          DownloadFailure.notDownloadable,
        ),
      ),
    );
  });

  test('an encrypted HLS episode cannot be downloaded', () async {
    sources.streams = [_hls('https://cdn.test/e2/720.m3u8')];
    final task = start(
      downloader(
        (_) => FakeReply.text(
          200,
          '#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI="k"\n#EXTINF:6,\ns1.ts\n',
        ),
      ),
    );

    await expectLater(
      task.done,
      throwsA(
        isA<OnlineDownloadException>().having(
          (error) => error.message,
          'message',
          downloadNotDownloadableMessage,
        ),
      ),
    );
  });

  test('an mp4 whose body broke off goes on with Range', () async {
    sources.streams = const [
      OnlineStream(
        url: 'https://cdn.test/e2/720.mp4',
        quality: 720,
        format: OnlineStreamFormat.mp4,
      ),
      OnlineStream(
        url: 'https://cdn.test/e2/720.m3u8',
        quality: 720,
        format: OnlineStreamFormat.hls,
      ),
    ];
    final ranges = <Object?>[];
    final updates = <OnlineDownloadProgress>[];
    final task = start(
      downloader((options) {
        final range = options.headers['Range'];
        ranges.add(range);
        if (range == null) {
          return const FakeReply.text(
            200,
            'abcd',
            headers: {
              'content-length': ['10'],
            },
          );
        }
        return const FakeReply.text(
          206,
          'efghij',
          headers: {
            'content-range': ['bytes 4-9/10'],
          },
        );
      }),
    );
    task.progress.listen(updates.add);

    final file = await task.done;

    expect(path.basename(file!.path), 'episode.mp4');
    expect(await file.readAsString(), 'abcdefghij');
    expect(ranges, [null, 'bytes=4-']);
    expect(updates.map((update) => update.videoHeight), everyElement(720));
    expect(stateLeft(), isFalse);
  });

  for (final total in [2, 8, null, 4]) {
    test('MP4 validates the total on a 416 response ($total)', () async {
      sources.streams = const [
        OnlineStream(
          url: 'https://cdn.test/e2/720.mp4',
          quality: 720,
          format: OnlineStreamFormat.mp4,
        ),
      ];
      await File(
        path.join(directory.path, 'episode.mp4'),
      ).writeAsString('OLD!');
      await File(
        path.join(directory.path, 'online_download.json'),
      ).writeAsString(
        jsonEncode({
          'format': 'mp4',
          'quality': 720,
          'pieces': 1,
          'done': 0,
          'bytes': 0,
        }),
      );
      final ranges = <Object?>[];
      final task = start(
        downloader((options) {
          final range = options.headers['Range'];
          ranges.add(range);
          if (range != null) {
            return FakeReply.text(
              416,
              '',
              headers: {
                if (total != null) 'content-range': ['bytes */$total'],
              },
            );
          }
          return const FakeReply.text(
            200,
            'NEW',
            headers: {
              'content-length': ['3'],
            },
          );
        }),
      );

      final file = (await task.done)!;
      expect(await file.readAsString(), total == 4 ? 'OLD!' : 'NEW');
      expect(ranges, ['bytes=4-', if (total != 4) null]);
      expect(stateLeft(), isFalse);
    });
  }

  test('an mp4 whose connection drops mid-body goes on with Range', () async {
    sources.streams = const [
      OnlineStream(
        url: 'https://cdn.test/e2/720.mp4',
        quality: 720,
        format: OnlineStreamFormat.mp4,
      ),
    ];
    final ranges = <Object?>[];
    final task = start(
      downloader((options) {
        final range = options.headers['Range'];
        ranges.add(range);
        if (range == null) {
          return const FakeReply.text(
            200,
            'abcd',
            headers: {
              'content-length': ['10'],
            },
            breakOff: SocketException('Connection reset by peer'),
          );
        }
        return const FakeReply.text(
          206,
          'efghij',
          headers: {
            'content-range': ['bytes 4-9/10'],
          },
        );
      }),
    );

    final file = await task.done;

    expect(await file!.readAsString(), 'abcdefghij');
    expect(ranges, [null, 'bytes=4-']);
  });
}

class _FakeOnlineSources implements OnlineSourcesRepository {
  final resolved = <String>[];
  List<OnlineStream> streams = const [];
  bool failResolve = false;

  /// Requests that fail for a network that is gone, before any answers.
  int offlineReleases = 0;
  int offlineResolves = 0;

  /// Gives each resolve its own streams, in place of [streams].
  FutureOr<List<OnlineStream>> Function()? onResolve;
  FutureOr<OnlineRelease> Function()? onRelease;

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) async {
    if (offlineReleases > 0) {
      offlineReleases--;
      throw const NetworkRequestException('offline');
    }
    return onRelease?.call() ?? _release;
  }

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) async {
    resolved.add(episodeId);
    if (failResolve) throw StateError('offline');
    if (offlineResolves > 0) {
      offlineResolves--;
      throw DioException.connectionError(
        requestOptions: RequestOptions(),
        reason: 'offline',
      );
    }
    return onResolve?.call() ?? streams;
  }

  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) => throw UnimplementedError();
}
