import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/downloads/presentation/pages/download_selection_page.dart';
import 'package:iris/shared/widgets/segmented_choice.dart';

import '../../../../helpers/memory_online_quality_preferences.dart';
import '../../../../helpers/test_app.dart';

const _online = DownloadSelectionArgs(
  animeId: '52991',
  animeTitle: 'Frieren',
  sourceTitle: 'AniLibria',
  magnet: 'online:anilibria/9542?anime=52991',
);

void main() {
  Future<MemoryOnlineQualityPreferences> pump(
    WidgetTester tester, {
    DownloadSelectionArgs args = _online,
    List<int> qualities = const [1080, 720, 480],
  }) async {
    final preferences = MemoryOnlineQualityPreferences(downloading: 720);
    await tester.pumpWidget(
      testApp(
        BlocProvider(
          create: (_) => DownloadSelectionCubit(
            args: args,
            repository: _EpisodesRepository(qualities),
            qualityPreferences: preferences,
          )..load(),
          child: DownloadSelectionPage(args: args, onQueued: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return preferences;
  }

  SegmentedChoice<int?> choice(WidgetTester tester) =>
      tester.widget<SegmentedChoice<int?>>(
        find.byKey(const Key('download_quality_choice')),
      );

  testWidgets('an online release is downloaded by episode, in a quality '
      'chosen over the list', (tester) async {
    final preferences = await pump(tester);

    expect(find.text('Download an episode'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    for (final label in ['Auto', '1080p', '720p', '480p']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(choice(tester).selected, 720);
    // An episode's size is not known before it loads.
    expect(find.text('0 B'), findsNothing);

    await tester.tap(find.text('480p'));
    await tester.pump();
    expect(choice(tester).selected, 480);
    expect(preferences.downloading, 480);
  });

  testWidgets('a release whose qualities are unknown offers no choice', (
    tester,
  ) async {
    await pump(tester, qualities: const []);

    expect(find.text('01'), findsOneWidget);
    expect(find.text('Quality'), findsNothing);
  });
}

class _EpisodesRepository extends MockDownloadsRepository {
  _EpisodesRepository(this.qualities);

  final List<int> qualities;

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    return PreparedDownloadSource(
      sourceToken: 'online',
      files: const [
        DownloadableFile(index: 1, name: '01', relativePath: '', size: 0),
        DownloadableFile(index: 2, name: '02', relativePath: '', size: 0),
      ],
      qualities: qualities,
    );
  }
}
