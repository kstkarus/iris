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
import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';

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

  testWidgets(
    'a downloaded title opens anime details and returns to Downloads',
    (tester) async {
      final repository =
          serviceLocator<DownloadsRepository>() as MockDownloadsRepository;
      await repository.enqueueDownload(
        source: const PreparedDownloadSource(sourceToken: 'mock', files: []),
        file: const DownloadableFile(
          index: 0,
          name: 'Episode 01.mkv',
          relativePath: 'Episode 01.mkv',
          size: 1,
        ),
        animeId: '5114',
        animeTitle: 'Fullmetal Alchemist: Brotherhood',
        sourceTitle: 'Downloaded batch',
      );
      final router = AppRouter.createRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(_app(router));
      await tester.pumpAndSettle();
      router.goNamed('downloads');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('download_title_anime:5114')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_title_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_title_open_anime')));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/anime/5114');
      expect(find.text('Fullmetal Alchemist: Brotherhood'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(router.state.uri.path, startsWith('/downloads'));
      expect(
        find.byKey(const Key('download_header_expanded_identity')),
        findsOneWidget,
      );
      expect(find.text('Episode 01'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
