import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/app_update/domain/entities/app_version.dart';

void main() {
  test('reads tags and package versions, build numbers aside', () {
    expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
    expect(AppVersion.tryParse('1.2.3+45'), const AppVersion(1, 2, 3));
    expect(AppVersion.tryParse('nightly'), isNull);
    expect(AppVersion.tryParse('1.2'), isNull);
  });

  test('compares part by part, not as text', () {
    expect(
      const AppVersion(1, 10, 0).isNewerThan(const AppVersion(1, 9, 9)),
      isTrue,
    );
    expect(
      const AppVersion(1, 2, 3).isNewerThan(const AppVersion(1, 2, 3)),
      isFalse,
    );
    expect(
      const AppVersion(1, 2, 3).isNewerThan(const AppVersion(2, 0, 0)),
      isFalse,
    );
  });
}
