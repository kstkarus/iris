import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/torrent/magnet_link.dart';

void main() {
  const hexHash = '065C4691DE84F964E143103B3BD0DE17BE5BFD0A';
  const hexHashLower = '065c4691de84f964e143103b3bd0de17be5bfd0a';
  // The same 20 bytes as [hexHash], in RFC 4648 base32 without padding.
  const base32Hash = 'AZOENEO6QT4WJYKDCA5TXUG6C67FX7IK';

  test('parses a hex info-hash and the display name', () {
    final link = MagnetLink.tryParse(
      '  magnet:?xt=urn:btih:$hexHash&dn=Death+Note%20S01&tr=udp%3A%2F%2Fa  ',
    );

    expect(link, isNotNull);
    expect(link!.infoHash, hexHashLower);
    expect(link.displayName, 'Death Note S01');
    expect(link.uri, startsWith('magnet:?'));
  });

  test('converts a base32 info-hash to lower-case hex', () {
    final link = MagnetLink.tryParse(
      'magnet:?xt=urn:btih:MFRGGZDFMZTWQ2LKNNWG23TPOBYXE43U',
    );

    expect(link?.infoHash, '6162636465666768696a6b6c6d6e6f7071727374');
    expect(link?.displayName, isNull);
  });

  test('gives one info-hash for the hex and base32 spellings', () {
    final hexLink = MagnetLink.tryParse('magnet:?xt=urn:btih:$hexHash');
    final base32Link = MagnetLink.tryParse('magnet:?xt=urn:btih:$base32Hash');
    final lowerBase32Link = MagnetLink.tryParse(
      'magnet:?xt=urn:btih:${base32Hash.toLowerCase()}',
    );

    expect(hexLink?.infoHash, hexHashLower);
    expect(base32Link?.infoHash, hexLink?.infoHash);
    expect(lowerBase32Link?.infoHash, hexLink?.infoHash);
  });

  test('reports upper-case and lower-case hex as the same info-hash', () {
    final upper = MagnetLink.tryParse('magnet:?xt=urn:btih:$hexHash');
    final lower = MagnetLink.tryParse('magnet:?xt=urn:btih:$hexHashLower');

    expect(upper?.infoHash, hexHashLower);
    expect(lower?.infoHash, hexHashLower);
  });

  test('uses the first BitTorrent xt when several are present', () {
    final link = MagnetLink.tryParse(
      'magnet:?xt=urn:btmh:1220abcd&xt=urn:btih:$hexHash',
    );

    expect(link?.infoHash, hexHashLower);
  });

  test('rejects text that is not a magnet with a valid btih', () {
    expect(MagnetLink.tryParse(''), isNull);
    expect(MagnetLink.tryParse('https://nyaa.si/view/1'), isNull);
    expect(MagnetLink.tryParse('magnet:?dn=only-a-name'), isNull);
    expect(MagnetLink.tryParse('magnet:?xt=urn:btih:tooshort'), isNull);
  });

  test('rejects malformed percent-encoding instead of throwing', () {
    expect(MagnetLink.tryParse('magnet:?xt=urn:btih:$hexHash&dn=%FF'), isNull);
    expect(
      MagnetLink.tryParse('magnet:?xt=urn:btih:$hexHash&dn=%E0%A4%A'),
      isNull,
    );
    expect(MagnetLink.tryParse('magnet:?xt=urn:btih:$hexHash&dn=%ZZ'), isNull);
    expect(MagnetLink.tryParse('magnet:?xt=urn:btih:%FF'), isNull);
  });

  test('never throws for malformed input', () {
    const inputs = ['%', 'magnet:?', 'magnet:?&&==&%', 'magnet:?xt=%'];
    for (final input in inputs) {
      expect(() => MagnetLink.tryParse(input), returnsNormally, reason: input);
    }
  });
}
