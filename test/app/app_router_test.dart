import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/app/di/service_locator.dart';
import 'package:iris/app/router/app_router.dart';
import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/features/auth/domain/repositories/auth_repository.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';

import '../helpers/test_app.dart';

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

  testWidgets('a friend opens on their own page', (tester) async {
    final router = AppRouter.createRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    router.pushNamed(
      'user-profile',
      pathParameters: {'id': '9001'},
      extra: const Friend(id: '9001', nickname: 'mock_friend', avatarUrl: ''),
    );
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/user/9001');
    expect(find.text('mock_friend'), findsOneWidget);
    expect(find.text('Nothing in “Watching”'), findsOneWidget);
  });

  test('torrent and player routes do not depend on a catalog title', () {
    final router = AppRouter.createRouter();
    addTearDown(router.dispose);

    expect(router.namedLocation('player'), '/player');
    expect(router.namedLocation('torrent-stream-files'), '/torrent/watch');
    expect(router.namedLocation('torrent-download-files'), '/torrent/download');
  });
}

/// The router under the session every page can read, as in the app.
Widget _app(GoRouter router) => BlocProvider(
  create: (_) => AuthCubit(repository: serviceLocator<AuthRepository>()),
  child: testRouterApp(router),
);
