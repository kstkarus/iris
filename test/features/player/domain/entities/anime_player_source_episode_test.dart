import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';

void main() {
  test('an online episode gives its own number and name', () {
    const file = PlayerVideoFile(
      index: 3,
      name: '04 «Пристанище душ»',
      size: 0,
      extension: '',
      episodeNumber: 4,
      title: '«Пристанище душ»',
    );
    const source = AnimePlayerSource(
      animeId: '52991',
      animeTitle: 'Фрирен',
      sourceTitle: 'AniLibria',
      sessionId: 'online:anilibria/9542',
      fileIndex: 3,
      fileName: '04 «Пристанище душ»',
      files: [file],
    );

    expect(file.number, 4);
    expect(file.displayName, '«Пристанище душ»');
    expect(source.episodeNumber, 4);
  });

  test('a torrent file is numbered and named by its file name', () {
    const file = PlayerVideoFile(
      index: 0,
      name: 'Season 1/[SubsPlease] Frieren - 05 (1080p).mkv',
      size: 1,
      extension: 'mkv',
    );
    const source = AnimePlayerSource(
      animeId: '',
      animeTitle: '',
      sourceTitle: '',
      sessionId: '7',
      fileIndex: 9,
      fileName: '[SubsPlease] Frieren - 06 (1080p).mkv',
      files: [file],
    );

    expect(file.number, 5);
    expect(file.displayName, '[SubsPlease] Frieren - 05 (1080p)');
    // The playing file is not among the files: its name still numbers it.
    expect(source.episodeNumber, 6);
  });
}
