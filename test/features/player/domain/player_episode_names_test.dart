import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/episode_metadata.dart';
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

    test('ignores fallback labels but keeps a partially named release', () {
      final files = [
        for (final (index, title) in [' 01 ', 'Серия 2', 'Episode 3'].indexed)
          PlayerVideoFile(
            index: index,
            name: '${index + 1}',
            size: 0,
            extension: 'm3u8',
            episodeNumber: index + 1,
            title: title,
          ),
      ];
      expect(hasEpisodeTitles(files), isFalse);

      files.add(
        const PlayerVideoFile(
          index: 3,
          name: '04',
          size: 0,
          extension: 'm3u8',
          episodeNumber: 4,
          title: ' The Journey Continues ',
        ),
      );
      expect(hasEpisodeTitles(files), isTrue);
    });

    test('does not mix external titles into a release with own titles', () {
      const files = [
        PlayerVideoFile(
          index: 0,
          name: '01',
          size: 0,
          extension: 'm3u8',
          episodeNumber: 1,
          title: '«Конец приключений»',
        ),
        PlayerVideoFile(
          index: 1,
          name: '02',
          size: 0,
          extension: 'm3u8',
          episodeNumber: 2,
          title: 'Episode 2',
        ),
      ];
      const metadata = {
        0: EpisodeMetadata(number: 1, title: "The Journey's End"),
        1: EpisodeMetadata(
          number: 2,
          title: "It Didn't Have to Be Magic...",
          filler: true,
        ),
      };

      expect(distinctEpisodeNames(files, metadata: metadata), {
        0: '«Конец приключений»',
        1: 'Episode 2',
      });
    });

    test('uses external titles when the release only has numeric labels', () {
      const files = [
        PlayerVideoFile(
          index: 0,
          name: '01',
          size: 0,
          extension: 'm3u8',
          episodeNumber: 1,
          title: 'Episode 1',
        ),
        PlayerVideoFile(
          index: 1,
          name: '02',
          size: 0,
          extension: 'm3u8',
          episodeNumber: 2,
          title: 'Серия 2',
        ),
      ];
      const metadata = {
        0: EpisodeMetadata(number: 1, title: "The Journey's End"),
        1: EpisodeMetadata(number: 2, title: "It Didn't Have to Be Magic..."),
      };

      expect(distinctEpisodeNames(files, metadata: metadata), {
        0: "The Journey's End",
        1: "It Didn't Have to Be Magic...",
      });
    });

    test('marks untitled releases as titled when metadata supplies names', () {
      final files = [
        _file(0, '[Group] Naruto - 01.mkv'),
        _file(1, '[Group] Naruto - 02.mkv'),
      ];
      const metadata = {
        0: EpisodeMetadata(number: 1, title: 'Enter: Naruto Uzumaki!'),
      };

      expect(hasEpisodeTitles(files), isFalse);
      expect(hasEpisodeTitles(files, metadata: metadata), isTrue);
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
