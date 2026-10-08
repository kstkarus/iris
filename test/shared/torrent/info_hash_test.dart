import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/torrent/info_hash.dart';

void main() {
  group('canonicalInfoHash', () {
    test('returns 40 hex digits in lower case', () {
      expect(
        canonicalInfoHash('065C4691DE84F964E143103B3BD0DE17BE5BFD0A'),
        '065c4691de84f964e143103b3bd0de17be5bfd0a',
      );
    });

    test('converts 32 base32 characters to the same 20 bytes in hex', () {
      expect(
        canonicalInfoHash('AZOENEO6QT4WJYKDCA5TXUG6C67FX7IK'),
        '065c4691de84f964e143103b3bd0de17be5bfd0a',
      );
      expect(
        canonicalInfoHash('azoeneo6qt4wjykdca5txug6c67fx7ik'),
        '065c4691de84f964e143103b3bd0de17be5bfd0a',
      );
      expect(
        canonicalInfoHash('AERUKZ4JVPG66AJDIVTYTK6N54ASGRLH'),
        '0123456789abcdef0123456789abcdef01234567',
      );
    });

    test('decodes all-zero and all-one base32 values', () {
      expect(
        canonicalInfoHash('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB'),
        '0000000000000000000000000000000000000001',
      );
      expect(canonicalInfoHash('77777777777777777777777777777777'), 'f' * 40);
    });

    test('returns null for anything else', () {
      const invalid = [
        '',
        '065C4691DE84F964E143103B3BD0DE17BE5BFD0', // 39 hex digits
        '065C4691DE84F964E143103B3BD0DE17BE5BFD0AA', // 41 hex digits
        '065C4691DE84F964E143103B3BD0DE17BE5BFD0G', // 40 characters, not hex
        'AZOENEO6QT4WJYKDCA5TXUG6C67FX7I', // 31 base32 characters
        'AZOENEO6QT4WJYKDCA5TXUG6C67FX7IKA', // 33 base32 characters
        'AZOENEO6QT4WJYKDCA5TXUG6C67FX7I1', // 1 is not a base32 digit
        'AZOENEO6QT4WJYKDCA5TXUG6C67FX7I8', // 8 is not a base32 digit
        'AZOENEO6QT4WJYKDCA5TXUG6C67FX7I-',
        'test-3',
      ];
      for (final value in invalid) {
        expect(canonicalInfoHash(value), isNull, reason: value);
      }
    });
  });
}
