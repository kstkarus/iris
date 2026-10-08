import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/downloads/presentation/pages/download_manager_page.dart';
import 'package:iris/features/downloads/presentation/pages/download_selection_page.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';

import '../../../../helpers/test_window.dart';

void main() {
  for (final entry in TestWindowSizes.all.entries) {
    // The sidebar takes its share, so only desktop windows fit both panes.
    // Content of 840 dp and up puts storage in a side pane.
    final isWide = entry.value.width >= 900;

    testWidgets('download manager adapts panes on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);
      final repository = await _repositoryWithDownloads(count: 3);
      await repository.pause(id: 'mock-1');

      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(repository: repository)..load(),
          child: DownloadManagerPage(onWatch: (_) {}),
        ),
      );

      final storage = tester.getRect(find.text('APP STORAGE'));
      final firstFile = tester.getRect(find.text('episode-00'));
      if (isWide) {
        expect(storage.left, greaterThan(firstFile.right));
      } else {
        // The files come first; storage follows them.
        expect(storage.top, greaterThan(firstFile.bottom));
      }
      expect(find.textContaining('PAUSED', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('download manager empty state fits on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);

      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) =>
              DownloadManagerCubit(repository: MockDownloadsRepository())
                ..load(),
          child: DownloadManagerPage(onWatch: (_) {}),
        ),
      );

      expect(
        find.text('Downloaded episodes will appear here.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('download selection keeps to the page frame on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);
      const args = DownloadSelectionArgs(
        animeId: '5114',
        animeTitle: 'Fullmetal Alchemist: Brotherhood',
        sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
        magnet: 'magnet:?xt=urn:btih:mock',
      );

      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadSelectionCubit(
            args: args,
            repository: MockDownloadsRepository(),
          )..load(),
          child: DownloadSelectionPage(args: args, onQueued: (_) {}),
        ),
      );

      final row = tester.getRect(
        find.ancestor(
          of: find.text('episode-01'),
          matching: find.byType(InkWell),
        ),
      );
      expect(find.text('episode-01'), findsOneWidget);
      expect(row.width, lessThanOrEqualTo(AdaptiveContentWidth.page));
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpApp(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

Future<MockDownloadsRepository> _repositoryWithDownloads({
  required int count,
}) async {
  final repository = MockDownloadsRepository();
  const source = PreparedDownloadSource(sourceToken: 'mock-source', files: []);
  for (var index = 0; index < count; index++) {
    await repository.enqueueDownload(
      source: source,
      file: DownloadableFile(
        index: index,
        name: 'episode-0$index.mkv',
        relativePath: 'episode-0$index.mkv',
        size: 734003200,
        extension: 'mkv',
      ),
      animeId: '5114',
      animeTitle: 'Fullmetal Alchemist: Brotherhood',
      sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
    );
  }
  return repository;
}
