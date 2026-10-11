import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/app/bootstrap/create_app.dart';

import 'test_window.dart';

/// Pumps frames until [finder] finds something, failing after [timeout].
Future<void> pumpUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  const step = Duration(milliseconds: 16);
  var elapsed = Duration.zero;
  while (elapsed < timeout) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
    elapsed += step;
  }
  fail('Widget was not found within $timeout: $finder');
}

/// The whole app on mock data, from empty preferences, settled on the
/// catalog.
Future<void> pumpMockApp(WidgetTester tester, {Size? size}) async {
  if (size != null) setTestWindowSize(tester, size);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(await createApp(useMocks: true));
  await pumpUntilVisible(tester, find.text('Fullmetal Alchemist: Brotherhood'));
  await tester.pumpAndSettle();
}
