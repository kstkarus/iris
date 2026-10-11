import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/torrent/video_file_extensions.dart';

void main() {
  group('isVideoExtension', () {
    test('accepts every video format the native engine streams', () {
      const extensions = [
        'mkv',
        'mp4',
        'webm',
        'avi',
        'mov',
        'm4v',
        'ts',
        'm2ts',
        'flv',
        'wmv',
        'mpg',
        'mpeg',
      ];
      for (final extension in extensions) {
        expect(isVideoExtension(extension), isTrue, reason: extension);
      }
    });

    test('ignores case', () {
      expect(isVideoExtension('MKV'), isTrue);
      expect(isVideoExtension('Wmv'), isTrue);
    });

    test('rejects audio, subtitles and unknown extensions', () {
      const extensions = [
        'mp3',
        'aac',
        'flac',
        'opus',
        'ogg',
        'wav',
        'ass',
        'srt',
        '',
      ];
      for (final extension in extensions) {
        expect(isVideoExtension(extension), isFalse, reason: extension);
      }
    });
  });

  group('videoFileExtension', () {
    test('reads the last extension, lowercased and without the dot', () {
      expect(videoFileExtension('Episode 01.MKV'), 'mkv');
      expect(videoFileExtension('show.s01e01.1080p.mp4'), 'mp4');
    });

    test('is empty when the name has no extension', () {
      expect(videoFileExtension('README'), '');
      expect(videoFileExtension('name.'), '');
      expect(videoFileExtension('.mkv'), '');
    });
  });

  group('isVideoFileName', () {
    test('accepts video files and rejects the rest', () {
      expect(isVideoFileName('Episode 01.mkv'), isTrue);
      expect(isVideoFileName('Episode 01.ass'), isFalse);
      expect(isVideoFileName('mkv'), isFalse);
    });
  });
}
