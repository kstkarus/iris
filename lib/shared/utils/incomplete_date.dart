/// An ISO date cut to what is known: `2028`, `2028-03` or `2028-03-15`.
///
/// Shikimori fills `date` with the first day of an unknown month or day, so
/// the date alone claims more than is known. Without a year (an older or
/// partial response) [date] is kept as it is.
String incompleteIsoDate({
  required int year,
  required int month,
  required int day,
  required String date,
}) {
  if (year <= 0) return date;
  final yearPart = year.toString().padLeft(4, '0');
  if (month <= 0) return yearPart;
  final monthPart = '$yearPart-${month.toString().padLeft(2, '0')}';
  if (day <= 0) return monthPart;
  return '$monthPart-${day.toString().padLeft(2, '0')}';
}

/// The year of an [incompleteIsoDate], or null when there is none.
int? yearOfIsoDate(String isoDate) {
  if (isoDate.length < 4) return null;
  return int.tryParse(isoDate.substring(0, 4));
}
