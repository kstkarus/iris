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
}
