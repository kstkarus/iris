import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Window sizes used by adaptive layout tests, in logical pixels.
abstract final class TestWindowSizes {
  static const phone = Size(390, 844);
  static const tablet = Size(1024, 768);
  static const desktop = Size(1920, 1080);

  static const all = {'phone': phone, 'tablet': tablet, 'desktop': desktop};
}

/// Resizes the test window and restores it when the test ends.
void setTestWindowSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
