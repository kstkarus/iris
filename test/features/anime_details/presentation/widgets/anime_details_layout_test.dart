import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_sections.dart';
import 'package:iris/shared/widgets/poster_image.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets(
    'long title and subtitle remain fully visible beside a compact poster',
    (tester) async {
      final sansLoader = FontLoader(DetailLayout.sansFont)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/MedeoSans-Regular.ttf').readAsBytesSync(),
            ),
          ),
        )
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/MedeoSans-Medium.ttf').readAsBytesSync(),
            ),
          ),
        );
      final pixelLoader = FontLoader(DetailLayout.pixelFont)
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File('assets/fonts/MedeoPixel-Grid.ttf').readAsBytesSync(),
            ),
          ),
        );
      await sansLoader.load();
      await pixelLoader.load();

      const posterWidth = 98.0;
      const posterHeight = posterWidth / PosterImage.aspectRatio;
      const head = AnimeDetailsPreview.fromSummary(
        AnimeSummary(
          id: '1',
          name:
              "Tensei shitara Slime Datta Ken Movie: Guren no Kizuna-hen — Director's Extended Edition",
          russian:
              'О моём перерождении в слизь: Фильм — Алые узы (Специальное расширенное режиссёрское издание)',
          kind: 'movie',
          score: 7.86,
          status: 'released',
          episodes: 1,
          episodesAired: 1,
          airedOn: '2022-11-25',
          posterUrl: '',
        ),
      );

      await tester.pumpWidget(
        testApp(
          theme: buildAppTheme(brightness: Brightness.dark),
          const MediaQuery(
            data: MediaQueryData(devicePixelRatio: 2.0),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 288 - posterWidth - 14,
                  child: AnimeDetailsTitles(
                    head: head,
                    maxSize: 40,
                    minSize: 16,
                    maxHeight: posterHeight,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      for (final text in [head.anime.name, head.anime.russian]) {
        final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(
          paragraph.size.height,
          greaterThanOrEqualTo(
            paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
          ),
        );
      }
      final title = tester.getRect(find.text(head.anime.name));
      final subtitle = tester.getRect(find.text(head.anime.russian));
      expect(title.bottom, lessThanOrEqualTo(subtitle.top));
    },
  );
}
