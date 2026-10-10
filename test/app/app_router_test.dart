import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/app/di/service_locator.dart';
import 'package:iris/app/router/app_router.dart';
import 'package:iris/features/auth/domain/repositories/auth_repository.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
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

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    router.goNamed('player', extra: 'bad');
    await tester.pumpAndSettle();

    expect(
      find.text('This screen was opened with invalid navigation data.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows route error when streaming file route receives invalid args',
    (tester) async {
      final router = AppRouter.createRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();

      router.goNamed('torrent-stream-files', extra: 'bad');
      await tester.pumpAndSettle();

      expect(
        find.text('This screen was opened with invalid navigation data.'),
        findsOneWidget,
      );
    },
  );

  test('torrent and player routes do not depend on a catalog title', () {
    final router = AppRouter.createRouter();
    addTearDown(router.dispose);

    expect(router.namedLocation('player'), '/player');
    expect(router.namedLocation('torrent-stream-files'), '/torrent/watch');
    expect(router.namedLocation('torrent-download-files'), '/torrent/download');
    expect(router.namedLocation('saved-torrents'), '/torrents');
  });
}

/// The router under the session every page can read, as in the app.
Widget _app(GoRouter router) => BlocProvider(
  create: (_) => AuthCubit(repository: serviceLocator<AuthRepository>()),
  child: MaterialApp.router(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  ),
);
