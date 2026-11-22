import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/repositories/online_releases_search.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/online_sources/presentation/widgets/online_releases_list.dart';

import '../../../../helpers/fake_watch_progress_repository.dart';
import '../../../../helpers/test_app.dart';

const _anilibria = OnlineRelease(
  provider: OnlineProvider.anilibria,
  id: '9542',
  dub: 'AniLibria',
  episodes: [OnlineEpisode(id: 'e1', number: 1)],
  bestQuality: 1080,
);

const _anidub = OnlineRelease(
  provider: OnlineProvider.yummyAnime,
  id: '10661:anidub',
  dub: 'AniDUB',
  episodes: [OnlineEpisode(id: 'e1', number: 1)],
  bestQuality: 720,
);

void main() {
  testWidgets(
    'incrementally reveals arriving dubs and collapses trailing stand-in',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final search = _StreamingOnlineSources();
      await _pumpList(tester, search);

      search.answers.add(const [_anilibria]);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('AniLibria'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Looking for online sources'),
        findsOneWidget,
      );

      search.answers.add(const [_anilibria, _anidub]);
      await tester.pump();
      expect(find.text('AniDUB'), findsOneWidget);

      await search.answers.close();
      await tester.pumpAndSettle();

      expect(find.text('AniLibria'), findsOneWidget);
      expect(find.text('AniDUB'), findsOneWidget);
      expect(find.bySemanticsLabel('Looking for online sources'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'stand-in removal completes immediately when animations are off',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      final semantics = tester.ensureSemantics();
      final search = _StreamingOnlineSources();
      await _pumpList(tester, search);

      search.answers.add(const [_anilibria]);
      await tester.pump();
      await tester.pump();
      expect(
        find.bySemanticsLabel('Looking for online sources'),
        findsOneWidget,
      );

      await search.answers.close();
      await tester.pump(Duration.zero);
      await tester.pump();
      await tester.pump();

      expect(find.text('AniLibria'), findsOneWidget);
      expect(find.bySemanticsLabel('Looking for online sources'), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      semantics.dispose();
    },
  );
}

Future<void> _pumpList(
  WidgetTester tester,
  _StreamingOnlineSources search,
) async {
  final online = OnlineReleasesCubit(
    shikimoriId: '52991',
    titles: const ['Frieren'],
    search: search,
  )..load();
  final history = WatchProgressCubit(
    repository: const FixedWatchProgressRepository(),
  )..load();
  addTearDown(online.close);
  addTearDown(history.close);

  await tester.pumpWidget(
    testApp(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: online),
          BlocProvider.value(value: history),
        ],
        child: const Scaffold(
          body: OnlineReleasesList(
            animeId: '52991',
            animeTitles: AnimeTitles(name: 'Frieren'),
          ),
        ),
      ),
    ),
  );
}

class _StreamingOnlineSources implements OnlineReleasesSearch {
  final answers = StreamController<List<OnlineRelease>>();

  @override
  Stream<List<OnlineRelease>> watchReleases({
    required String shikimoriId,
    required List<String> titles,
  }) => answers.stream;
}
