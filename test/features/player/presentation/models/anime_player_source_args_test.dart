import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';

void main() {
  WatchProgress progress({required Duration position}) => WatchProgress(
    torrentKey: 'hash',
    fileIndex: 3,
    fileName: 'Episode 04.mkv',
    magnet: 'magnet:?xt=urn:btih:hash',
    sourceTitle: '[Group] Frieren',
    position: position,
    duration: const Duration(minutes: 24),
    updatedAt: DateTime(2026),
    animeId: '52991',
    animeTitle: 'Sousou no Frieren',
  );

  test('resuming opens the file it stopped in', () {
    final args = AnimePlayerSourceArgs.resume(
      progress(position: const Duration(minutes: 5)),
    );

    expect(args.animeId, '52991');
    expect(args.animeTitle, 'Sousou no Frieren');
    expect(args.sourceTitle, '[Group] Frieren');
    expect(args.magnet, 'magnet:?xt=urn:btih:hash');
    expect(args.autoOpenFileIndex, 3);
  });

  test('a finished file opens the picker instead', () {
    final args = AnimePlayerSourceArgs.resume(
      progress(position: const Duration(minutes: 23)),
    );

    expect(args.autoOpenFileIndex, isNull);
  });
}
