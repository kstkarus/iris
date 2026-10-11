import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/motion_duration.dart';

void main() {
  const duration = Duration(milliseconds: 150);

  Future<Duration> resolve(WidgetTester tester, {required bool reduce}) async {
    late Duration resolved;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Builder(
          builder: (context) {
            resolved = motionDuration(context, duration);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return resolved;
  }

  testWidgets('keeps the duration while animations are on', (tester) async {
    expect(await resolve(tester, reduce: false), duration);
  });

  testWidgets('drops it when the system asks for less motion', (tester) async {
    expect(await resolve(tester, reduce: true), Duration.zero);
  });
}
