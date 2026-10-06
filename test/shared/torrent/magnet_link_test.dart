import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/torrent/magnet_link.dart';

void main() {
  const hexHash = '065C4691DE84F964E143103B3BD0DE17BE5BFD0A';

  test('parses a hex info-hash and the display name', () {
    final link = MagnetLink.tryParse(
      '  magnet:?xt=urn:btih:$hexHash&dn=Death+Note%20S01&tr=udp%3A%2F%2Fa  ',
    );

    expect(link, isNotNull);
    expect(link!.infoHash, hexHash.toLowerCase());
    expect(link.displayName, 'Death Note S01');
    expect(link.uri, startsWith('magnet:?'));
  });

  test('accepts a base32 info-hash', () {
    final link = MagnetLink.tryParse(
      'magnet:?xt=urn:btih:MFRGGZDFMZTWQ2LKNNWG23TPOBYXE43U',
    );

    expect(link?.infoHash, 'mfrggzdfmztwq2lknnwg23tpobyxe43u');
    expect(link?.displayName, isNull);
  });

  test('uses the first BitTorrent xt when several are present', () {
    final link = MagnetLink.tryParse(
      'magnet:?xt=urn:btmh:1220abcd&xt=urn:btih:$hexHash',
    );

    expect(link?.infoHash, hexHash.toLowerCase());
  });

  test('rejects text that is not a magnet with a valid btih', () {
    expect(MagnetLink.tryParse(''), isNull);
    expect(MagnetLink.tryParse('https://nyaa.si/view/1'), isNull);
    expect(MagnetLink.tryParse('magnet:?dn=only-a-name'), isNull);
    expect(MagnetLink.tryParse('magnet:?xt=urn:btih:tooshort'), isNull);
    expect(
      MagnetLink.tryParse('magnet:?xt=urn:btih:$hexHash&dn=%E0%A4%A'),
      isNotNull,
    );
  });
}
