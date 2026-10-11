import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/torrent/torrent_key.dart';

void main() {
  const hexHash = '065C4691DE84F964E143103B3BD0DE17BE5BFD0A';
  const hexKey = '065c4691de84f964e143103b3bd0de17be5bfd0a';
  // The same 20 bytes as [hexHash], in RFC 4648 base32 without padding.
  const base32Hash = 'AZOENEO6QT4WJYKDCA5TXUG6C67FX7IK';

  group('torrentKeyFromMagnet', () {
    test('gives the same key for the hex and base32 spellings', () {
      expect(torrentKeyFromMagnet('magnet:?xt=urn:btih:$hexHash'), hexKey);
      expect(torrentKeyFromMagnet('magnet:?xt=urn:btih:$base32Hash'), hexKey);
      expect(
        torrentKeyFromMagnet(
          'magnet:?dn=Show&xt=urn:btih:${base32Hash.toLowerCase()}',
        ),
        hexKey,
      );
    });

    test('gives the same key for upper-case and lower-case hex', () {
      expect(
        torrentKeyFromMagnet('magnet:?xt=urn:btih:${hexHash.toLowerCase()}'),
        torrentKeyFromMagnet('magnet:?xt=urn:btih:$hexHash'),
      );
    });

    test('keeps the historical normalization for other btih values', () {
      expect(torrentKeyFromMagnet('magnet:?xt=urn:btih:test-3'), 'test3');
      expect(
        torrentKeyFromMagnet('magnet:?xt=urn:btih:ABCDEF1234'),
        'abcdef1234',
      );
    });

    test('ignores display name and trackers', () {
      expect(
        torrentKeyFromMagnet('magnet:?xt=urn:btih:abc&tr=udp://a'),
        torrentKeyFromMagnet('magnet:?dn=x&xt=urn:btih:ABC'),
      );
    });

    test('falls back to a stable hash without btih', () {
      const magnet = 'magnet:?dn=only-a-name';
      expect(torrentKeyFromMagnet(magnet), torrentKeyFromMagnet(magnet));
      expect(torrentKeyFromMagnet(magnet), isNotEmpty);
    });

    test('matches the xt parameter name in any case, like MagnetLink', () {
      expect(torrentKeyFromMagnet('magnet:?XT=urn:btih:$hexHash'), hexKey);
    });

    test('ignores a malformed display name', () {
      expect(
        torrentKeyFromMagnet('magnet:?xt=urn:btih:$hexHash&dn=%FF'),
        hexKey,
      );
      expect(
        torrentKeyFromMagnet('magnet:?xt=urn:btih:$hexHash&dn=%E0%A4%A'),
        hexKey,
      );
    });

    test('falls back to the whole-link hash for a malformed xt', () {
      const magnet = 'magnet:?xt=urn:btih:%FF';

      expect(torrentKeyFromMagnet(magnet), torrentKeyFromMagnet(magnet));
      expect(torrentKeyFromMagnet(magnet), isNot(hexKey));
    });

    test('never throws for malformed input', () {
      const inputs = [
        '%',
        'magnet:?',
        'magnet:?&&==&%',
        'magnet:?xt=%',
        'magnet:?xt=urn:btih:%E0%A4%A',
        'magnet:?xt=urn:btih:$hexHash&dn=%E0%A4%A',
      ];
      for (final input in inputs) {
        expect(
          () => torrentKeyFromMagnet(input),
          returnsNormally,
          reason: input,
        );
      }
    });
  });
}
