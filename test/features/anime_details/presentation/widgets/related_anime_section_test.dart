import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/anime_details/domain/entities/related_anime.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/related_anime_section.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  test('leaves out promos and lists before and after first, by date', () {
    final shown = relatedToShow([
      _anime('side-late', AnimeRelation.sideStory, airedOn: '2024-01-01'),
      _anime('promo', AnimeRelation.other, kind: 'pv'),
      _anime('side-undated', AnimeRelation.sideStory, airedOn: ''),
      _anime('sequel', AnimeRelation.sequel),
      _anime('side-early', AnimeRelation.sideStory, airedOn: '2020-01-01'),
      _anime('clip', AnimeRelation.other, kind: 'music'),
      _anime('prequel', AnimeRelation.prequel),
    ]);

    expect(shown.map((related) => related.anime.id), [
      'prequel',
      'sequel',
      'side-early',
      'side-late',
      'side-undated',
    ]);
  });

  testWidgets('a long franchise folds after the first rows', (tester) async {
    await tester.pumpWidget(
      _app([
        for (var index = 0; index < 6; index++)
          _anime('$index', AnimeRelation.sideStory),
      ]),
    );

    expect(_rows, findsNWidgets(RelatedAnimeSection.visibleRows));
    expect(find.text('3 more'), findsOneWidget);

    await tester.tap(find.byKey(const Key('related_anime_more')));
    await tester.pumpAndSettle();
    expect(_rows, findsNWidgets(6));
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('one hidden row is shown rather than folded', (tester) async {
    await tester.pumpWidget(
      _app([
        for (var index = 0; index < 4; index++)
          _anime('$index', AnimeRelation.sideStory),
      ]),
    );

    expect(_rows, findsNWidgets(4));
    expect(find.byKey(const Key('related_anime_more')), findsNothing);
  });

  testWidgets('a row tells the relation and opens the title page', (
    tester,
  ) async {
    Object? opened;
    await tester.pumpWidget(
      _app([
        _anime(
          '59978',
          AnimeRelation.sequel,
          name: 'Sousou no Frieren 2nd Season',
          russian: 'Провожающая в последний путь Фрирен 2',
          airedOn: '2026-01-16',
        ),
      ], onOpen: (extra) => opened = extra),
    );

    expect(find.text('SEQUEL · TV · 2026'), findsOneWidget);
    expect(find.text('Провожающая в последний путь Фрирен 2'), findsOneWidget);

    await tester.tap(find.text('Sousou no Frieren 2nd Season'));
    await tester.pumpAndSettle();

    expect(
      opened,
      isA<AnimeDetailsPreview>()
          .having((preview) => preview.anime.id, 'id', '59978')
          .having(
            (preview) => preview.anime.posterUrl,
            'poster',
            'poster-59978',
          ),
    );
  });

  testWidgets('a franchise of promos alone shows no section', (tester) async {
    await tester.pumpWidget(
      _app([_anime('cm', AnimeRelation.other, kind: 'cm')]),
    );

    expect(find.text('Related'), findsNothing);
  });
}

final _rows = find.byWidgetPredicate(
  (widget) =>
      widget is InkWell &&
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('related_anime_'),
);

Widget _app(
  List<RelatedAnime> related, {
  void Function(Object? extra)? onOpen,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            child: RelatedAnimeSection(related: related),
          ),
        ),
      ),
      GoRoute(
        path: '/anime/:id',
        name: 'anime-details',
        builder: (_, state) {
          onOpen?.call(state.extra);
          return const SizedBox.shrink();
        },
      ),
    ],
  );
  return MaterialApp.router(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

RelatedAnime _anime(
  String id,
  AnimeRelation relation, {
  String name = '',
  String russian = '',
  String kind = 'tv',
  String airedOn = '2023-01-01',
}) => RelatedAnime(
  relation: relation,
  anime: AnimeSummary(
    id: id,
    name: name.isEmpty ? 'Title $id' : name,
    russian: russian,
    kind: kind,
    score: 0,
    status: 'released',
    episodes: 12,
    episodesAired: 12,
    airedOn: airedOn,
    posterUrl: 'poster-$id',
  ),
);
