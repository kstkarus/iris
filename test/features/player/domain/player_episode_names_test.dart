import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';

PlayerVideoFile _file(int index, String name) =>
    PlayerVideoFile(index: index, name: name, size: 1, extension: 'mkv');

void main() {
  group('distinctEpisodeNames', () {
    test('keeps what a file names beyond the series and its number', () {
      final names = distinctEpisodeNames([
        _file(0, "[Group] Frieren - 01 - The Journey's End [1080p].mkv"),
        _file(
          1,
          '[Group] Frieren - 02 - It Didn’t Have to Be Magic [1080p].mkv',
        ),
      ]);

      expect(names, {0: "The Journey's End", 1: 'It Didn’t Have to Be Magic'});
    });

    test('gives nothing for files told apart by their number only', () {
      expect(
        distinctEpisodeNames([
          _file(0, '[Group] Death Note 01 [BDRip 1080p].mkv'),
          _file(1, '[Group] Death Note 02 [BDRip 1080p].mkv'),
          _file(2, '[Group] Death Note 19 [BDRip 1080p].mkv'),
        ]),
        isEmpty,
      );
      expect(distinctEpisodeNames([_file(0, 'Movie.mkv')]), isEmpty);
    });
  });

  group('episodeNumberLabel', () {
    test('shows the episode number the name gives', () {
      expect(episodeNumberLabel(_file(7, 'Show - 04.mkv'), 0), '04');
    });

    test('falls back to the place in the source', () {
      expect(episodeNumberLabel(_file(7, 'Movie.mkv'), 2), '03');
    });
  });
}
