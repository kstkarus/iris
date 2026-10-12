import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/torrent/magnet_link.dart';
import 'package:iris/shared/torrent/torrent_file.dart';

import '../../helpers/bencode.dart';

void main() {
  final pieces = Uint8List(20);

  test('a batch reads as its name, size, files and trackers', () {
    final info = {
      'files': [
        {
          'length': 1000,
          'path': ['Death Note 01.mkv'],
        },
        {
          'length': 500,
          'path': ['Death Note 02.mkv'],
        },
      ],
      'name': 'Death Note [S01]',
      'piece length': 16384,
      'pieces': pieces,
    };
    final bytes = encodeBencode({
      'announce': 'udp://one.example:6969',
      'announce-list': [
        ['udp://one.example:6969'],
        ['http://two.example/announce'],
      ],
      'info': info,
    });

    final torrent = TorrentFile.tryParse(bytes)!;

    expect(torrent.infoHash, sha1.convert(encodeBencode(info)).toString());
    expect(torrent.name, 'Death Note [S01]');
    expect(torrent.size, 1500);
    expect(torrent.fileCount, 2);
    expect(torrent.trackers, [
      'udp://one.example:6969',
      'http://two.example/announce',
    ]);
  });

  test('stands in as a magnet link with the same torrent', () {
    final bytes = encodeBencode({
      'info': {
        'length': 42,
        'name': 'Тетрадь смерти 01 & 02.mkv',
        'piece length': 16384,
        'pieces': pieces,
      },
      'announce': 'http://tracker.example/announce?passkey=a&b',
    });
    final torrent = TorrentFile.tryParse(bytes)!;

    final link = MagnetLink.tryParse(torrent.magnet)!;

    expect(torrent.fileCount, 1);
    expect(link.infoHash, torrent.infoHash);
    expect(link.displayName, 'Тетрадь смерти 01 & 02.mkv');
    expect(Uri.parse(torrent.magnet).queryParametersAll['tr'], [
      'http://tracker.example/announce?passkey=a&b',
    ]);
  });

  test('prefers the UTF-8 name a torrent gives besides its own', () {
    final bytes = encodeBencode({
      'info': {
        'length': 1,
        'name': 'legacy',
        'name.utf-8': 'Унифицированное',
        'piece length': 1,
        'pieces': pieces,
      },
    });

    expect(TorrentFile.tryParse(bytes)?.name, 'Унифицированное');
  });

  test('anything else is not a torrent', () {
    expect(
      TorrentFile.tryParse(Uint8List.fromList(utf8.encode('hello'))),
      isNull,
    );
    expect(TorrentFile.tryParse(Uint8List(0)), isNull);
    expect(TorrentFile.tryParse(encodeBencode({'announce': 'x'})), isNull);
    expect(
      TorrentFile.tryParse(
        encodeBencode({
          'info': {'length': 1, 'name': 'x'},
        }),
      ),
      isNull,
      reason: 'a v2-only torrent has no v1 pieces',
    );
    final cut = encodeBencode({
      'info': {'length': 1, 'name': 'x', 'pieces': pieces},
    });
    expect(TorrentFile.tryParse(Uint8List.sublistView(cut, 0, 30)), isNull);
  });
}
