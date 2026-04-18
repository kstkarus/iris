import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';
import 'package:iris/features/player/data/utils/player_debug_formatter.dart';

void main() {
  test('redacts long magnet links for safer diagnostics', () {
    final result = redactMagnet(
      'magnet:?xt=urn:btih:1234567890ABCDEF1234567890ABCDEF12345678&dn=test',
    );

    expect(result, startsWith('magnet:?xt=urn:btih:'));
    expect(result, contains('...'));
    expect(result, endsWith('dn=test'));
  });

  test('summarizes torrent files into one readable line', () {
    const files = [
      TorrentFileDescriptor(
        index: 1,
        name: 'episode-01.mkv',
        size: 1200,
        isStreamable: true,
      ),
      TorrentFileDescriptor(
        index: 2,
        name: 'cover.jpg',
        size: 50,
        isStreamable: false,
      ),
    ];

    final result = summarizeTorrentFiles(files);

    expect(result, contains('[1] episode-01.mkv'));
    expect(result, contains('streamable=true'));
    expect(result, contains('[2] cover.jpg'));
    expect(result, contains('streamable=false'));
  });
}
