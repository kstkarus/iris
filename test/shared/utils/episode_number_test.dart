import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/episode_number.dart';

void main() {
  const cases = {
    '[SubsPlease] Sousou no Frieren - 05 (1080p) [ABCD1234].mkv': 5,
    '[Erai-raws] Sousou no Frieren - 12v2 [1080p][Multiple Subtitle].mkv': 12,
    'Frieren.S01E07.1080p.WEB.x264.mkv': 7,
    'Season 1/Death Note 15.mkv': 15,
    '[Group] Title [03][BDRip 1080p].mkv': 3,
    'Frieren Episode 9.mp4': 9,
    'Фрирен серия 4.mkv': 4,
    '[千夏字幕组][葬送的芙莉莲][第28話][1080p].mp4': 28,
    '08.mkv': 8,
    'One Piece - 1100 (1080p).mkv': 1100,
    // Named as episodes, numbers that look like a resolution count.
    '[SubsPlease] One Piece - 1080 (1080p) [ABCD1234].mkv': 1080,
    'One Piece S21E1080.mkv': 1080,
    'Detective Conan - 720 [1080p].mkv': 720,
    'Naruto Shippuden Episode 480.mkv': 480,
  };
  for (final MapEntry(key: name, value: episode) in cases.entries) {
    test('reads episode $episode from "$name"', () {
      expect(episodeNumberFromFileName(name), episode);
    });
  }

  const noEpisode = [
    'Sousou no Frieren (2023) [1080p].mkv',
    '[Group] Movie [BD 1080p x265 10bit].mkv',
    'Frieren Batch.mkv',
    'Kimi no Na wa - 2016 [BD 1080p].mkv',
  ];
  for (final name in noEpisode) {
    test('finds no episode in "$name"', () {
      expect(episodeNumberFromFileName(name), isNull);
    });
  }
}
