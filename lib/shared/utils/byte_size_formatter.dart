import 'package:intl/intl.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

/// File size in binary units with one decimal from megabytes up, in the
/// locale's digits and unit names, e.g. `613,9 МБ`. [compact] drops the
/// decimal from 10 units up too, for figures that change every second:
/// `12 МБ`, `1,5 МБ`.
String formatByteSize(
  AppLocalizations l10n,
  int bytes, {
  bool compact = false,
}) {
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
  final whole = unit < 2 || (compact && value >= 10);
  final number = NumberFormat.decimalPatternDigits(
    locale: l10n.localeName,
    decimalDigits: whole ? 0 : 1,
  ).format(value);
  return '$number ${units[unit]}';
}

/// A transfer rate, e.g. `1,5 МБ/с`; [compact] as in [formatByteSize].
String formatTransferRate(
  AppLocalizations l10n,
  int bytesPerSecond, {
  bool compact = true,
}) {
  return l10n.playerRate(
    formatByteSize(l10n, bytesPerSecond, compact: compact),
  );
}
