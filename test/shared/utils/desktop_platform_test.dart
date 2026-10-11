import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/desktop_platform.dart';

void main() {
  test('detects desktop platforms', () {
    expect(isDesktopPlatformFor(TargetPlatform.windows), isTrue);
    expect(isDesktopPlatformFor(TargetPlatform.linux), isTrue);
    expect(isDesktopPlatformFor(TargetPlatform.macOS), isTrue);
    expect(isDesktopPlatformFor(TargetPlatform.android), isFalse);
    expect(isDesktopPlatformFor(TargetPlatform.iOS), isFalse);
  });
}
