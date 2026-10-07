import 'package:intl/intl.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

/// File size in binary units with one decimal from megabytes up, in the
/// locale's digits and unit names, e.g. `613,9 МБ`.
String formatByteSize(AppLocalizations l10n, int bytes) {
  final units = [
    l10n.byteUnitB,
    l10n.byteUnitKB,
    l10n.byteUnitMB,
    l10n.byteUnitGB,
  ];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final number = NumberFormat.decimalPatternDigits(
    locale: l10n.localeName,
    decimalDigits: unit < 2 ? 0 : 1,
  ).format(value);
  return '$number ${units[unit]}';
}
