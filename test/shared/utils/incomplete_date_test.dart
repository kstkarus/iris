import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/incomplete_date.dart';

void main() {
  test('keeps only the known parts of a date', () {
    // Shikimori sends the first of January for a title known by its year.
    expect(
      incompleteIsoDate(year: 2028, month: 0, day: 0, date: '2028-01-01'),
      '2028',
    );
    expect(
      incompleteIsoDate(year: 2028, month: 3, day: 0, date: '2028-03-01'),
      '2028-03',
    );
    expect(
      incompleteIsoDate(year: 2028, month: 3, day: 5, date: '2028-03-05'),
      '2028-03-05',
    );
  });

  test('falls back to the date without a year', () {
    expect(
      incompleteIsoDate(year: 0, month: 0, day: 0, date: '2009-04-05'),
      '2009-04-05',
    );
    expect(incompleteIsoDate(year: 0, month: 0, day: 0, date: ''), '');
  });

  test('reads the year of any precision', () {
    expect(yearOfIsoDate('2028'), 2028);
    expect(yearOfIsoDate('2028-03-05'), 2028);
    expect(yearOfIsoDate(''), isNull);
  });
}
