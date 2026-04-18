import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/app/di/service_locator.dart';
import 'package:iris/app/router/app_router.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(useMocks: true, reset: true);
  });

  tearDown(() async {
    await serviceLocator.reset();
  });

  testWidgets('shows route error when player route receives invalid args', (
    tester,
  ) async {
    final router = AppRouter.createRouter();

    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    router.goNamed(
      'anime-player',
      pathParameters: {'id': '5114'},
      extra: 'bad',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('This screen was opened with invalid navigation data.'),
      findsOneWidget,
    );
  });
}
