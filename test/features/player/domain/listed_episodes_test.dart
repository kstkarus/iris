import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/listed_episodes.dart';

PlayerVideoFile _file(int index, String name, {num? number}) => PlayerVideoFile(
  index: index,
  name: name,
  size: 1,
  extension: 'mkv',
  episodeNumber: number,
);

void main() {
  test('an online release counts its own numbers, specials aside', () {
    final files = [
      _file(1, '01', number: 1),
      _file(2, '02', number: 2),
      _file(100250, '02.5', number: 2.5),
      _file(3, '03', number: 3),
    ];

    expect(filesCountedInList(files, 2), {1, 2});
    expect(filesCountedInList(files, 0), isEmpty);
  });

  test('a torrent numbered from 1 counts by the numbers in its names', () {
    final files = [
      _file(0, '[Group] Title - 01 [1080p].mkv'),
      _file(1, '[Group] Title - 02 [1080p].mkv'),
      _file(2, '[Group] Title - 03 [1080p].mkv'),
      _file(3, 'Bonus interview.mkv'),
    ];

    expect(filesCountedInList(files, 2), {0, 1});
  });

  test('a season numbered on from the last counts nothing', () {
    final files = [
      _file(0, '[Group] Title - 13 [1080p].mkv'),
      _file(1, '[Group] Title - 14 [1080p].mkv'),
    ];

    expect(filesCountedInList(files, 1), isEmpty);
  });

  test('a pack of seasons each from 1 counts nothing', () {
    final files = [
      _file(0, 'Season 1/Title - 01.mkv'),
      _file(1, 'Season 1/Title - 02.mkv'),
      _file(2, 'Season 2/Title - 01.mkv'),
      _file(3, 'Season 2/Title - 02.mkv'),
    ];

    expect(filesCountedInList(files, 1), isEmpty);
  });
}
