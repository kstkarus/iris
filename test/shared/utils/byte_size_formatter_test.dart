import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ru = lookupAppLocalizations(const Locale('ru'));
  const mib = 1024 * 1024;

  String size(int bytes, {bool compact = false}) =>
      formatByteSize(en, bytes, compact: compact);

  test('keeps bytes and kilobytes whole', () {
    expect(size(512), '512 ${en.byteUnitB}');
    expect(size(1536), '2 ${en.byteUnitKB}');
    expect(size(1536, compact: true), '2 ${en.byteUnitKB}');
  });

  test('gives one decimal from megabytes up', () {
    expect(size(mib * 3 ~/ 2), '1.5 ${en.byteUnitMB}');
    expect(size((12.3 * mib).round()), '12.3 ${en.byteUnitMB}');
    expect(size(2 * 1024 * mib), '2.0 ${en.byteUnitGB}');
  });

  test('compact drops the decimal from ten units up only', () {
    expect(size(mib * 3 ~/ 2, compact: true), '1.5 ${en.byteUnitMB}');
    expect(size((12.3 * mib).round(), compact: true), '12 ${en.byteUnitMB}');
  });

  test('uses the locale digits and unit names', () {
    expect(formatByteSize(ru, mib * 3 ~/ 2), '1,5 ${ru.byteUnitMB}');
  });

  test('formats a rate compactly unless asked otherwise', () {
    final rate = (12.3 * mib).round();

    expect(formatTransferRate(en, rate), en.playerRate('12 ${en.byteUnitMB}'));
    expect(
      formatTransferRate(en, rate, compact: false),
      en.playerRate('12.3 ${en.byteUnitMB}'),
    );
  });
}
