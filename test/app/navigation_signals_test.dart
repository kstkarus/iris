import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/app.dart';
import 'package:iris/app/router/app_shell_page.dart';
import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_download_repository.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/settings/presentation/widgets/about_app_section.dart';
import 'package:iris/features/settings/presentation/widgets/settings_icon_button.dart';

import '../features/app_update/app_update_test_doubles.dart';
import '../helpers/test_window.dart';

DownloadItem _download(DownloadStatus status) => DownloadItem(
  id: 'dl-1',
  animeId: '1',
  animeTitle: 'Frieren',
  sourceTitle: 'Subs',
  magnet: 'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567',
  fileIndex: 0,
  fileName: '01.mkv',
  relativePath: '01.mkv',
  localPath: '/tmp/01.mkv',
  totalBytes: 1000,
  downloadedBytes: 250,
  downloadRateBytesPerSecond: 100,
  peers: 2,
  status: status,
  createdAt: DateTime(2026),
);

class _FakeDownloadsRepository implements DownloadsRepository {
  final _controller = StreamController<List<DownloadItem>>.broadcast();

  void emit(List<DownloadItem> items) => _controller.add(items);

  Future<void> dispose() => _controller.close();

  @override
  Stream<List<DownloadItem>> watchDownloads() => _controller.stream;

  @override
  Future<DownloadStorageUsage> calculateStorageUsage() =>
      throw UnimplementedError();

  @override
  Future<bool> clearCache() => throw UnimplementedError();

  @override
  Future<bool> delete({required String id}) => throw UnimplementedError();

  @override
  Future<Set<String>> deleteMany({required Iterable<String> ids}) =>
      throw UnimplementedError();

  @override
  Future<void> disposePreparedSource({required String sourceToken}) =>
      throw UnimplementedError();

  @override
  Future<void> downloadNext({required String id}) => throw UnimplementedError();

  @override
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
    String animeRussian = '',
    String animeEnglish = '',
    String posterUrl = '',
    int? quality,
  }) => throw UnimplementedError();

  @override
  Future<DownloadItem?> findCompletedById({required String id}) =>
      throw UnimplementedError();

  @override
  Future<void> pause({required String id}) => throw UnimplementedError();

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) => throw UnimplementedError();

  @override
  Future<void> reorderQueue({required List<String> ids}) =>
      throw UnimplementedError();

  @override
  Future<void> resume({required String id}) => throw UnimplementedError();

  @override
  Future<void> retry({required String id}) => throw UnimplementedError();

  @override
  Stream<Map<int, DownloadItem>> watchSourceDownloads({
    required String magnet,
  }) => const Stream.empty();
}

class _FakeUpdateDownloads implements AppUpdateDownloadRepository {
  @override
  Future<void> cancel() async {}
  @override
  Future<bool> canInstall() async => true;
  @override
  Future<String> download(
    AppRelease release, {
    required void Function(int received, int total) onProgress,
  }) => Completer<String>().future;
  @override
  Future<void> install(String path) async {}
  @override
  Future<void> openInstallPermissionSettings() async {}
  @override
  Future<String?> restore(AppRelease release) async => null;
}

GoRouter _shellRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShellPage(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Catalog body')),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/downloads',
              builder: (_, _) => const Scaffold(body: Text('Downloads body')),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SettingsIconButton(onPressed: () {}),
                      const AboutAppSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets(
    'desktop Downloads signal appears only when inactive and never shifts tabs',
    (tester) async {
      setTestWindowSize(tester, TestWindowSizes.desktop);
      final downloads = _FakeDownloadsRepository();
      final router = _shellRouter();
      addTearDown(() async {
        router.dispose();
        await downloads.dispose();
      });

      await tester.pumpWidget(
        IrisApp(router: router, downloadsRepository: downloads),
      );
      await tester.pumpAndSettle();

      final catalogBefore = tester.getTopLeft(find.text('Catalog'));
      final downloadsBefore = tester.getTopLeft(find.text('Downloads'));
      final profileBefore = tester.getTopLeft(find.text('Profile'));
      expect(find.byKey(AppShellPage.downloadsSignalKey), findsNothing);

      downloads.emit([_download(DownloadStatus.downloading)]);
      await tester.pumpAndSettle();

      expect(find.byKey(AppShellPage.downloadsSignalKey), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Downloads, downloading'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(tester.getTopLeft(find.text('Catalog')), catalogBefore);
      expect(tester.getTopLeft(find.text('Downloads')), downloadsBefore);
      expect(tester.getTopLeft(find.text('Profile')), profileBefore);

      await tester.tap(find.text('Downloads'));
      await tester.pumpAndSettle();
      expect(find.byKey(AppShellPage.downloadsSignalKey), findsNothing);

      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      expect(find.byKey(AppShellPage.downloadsSignalKey), findsOneWidget);

      downloads.emit([_download(DownloadStatus.paused)]);
      await tester.pumpAndSettle();
      expect(find.byKey(AppShellPage.downloadsSignalKey), findsNothing);
    },
  );

  testWidgets(
    'phone Downloads signal stays aligned at 200% text on 320dp width',
    (tester) async {
      setTestWindowSize(tester, const Size(320, 640));
      final downloads = _FakeDownloadsRepository();
      final router = _shellRouter();
      addTearDown(() async {
        router.dispose();
        await downloads.dispose();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: IrisApp(router: router, downloadsRepository: downloads),
        ),
      );
      await tester.pumpAndSettle();

      final catalogBefore = tester.getTopLeft(find.text('Catalog'));
      final profileBefore = tester.getTopLeft(find.text('Profile'));

      downloads.emit([_download(DownloadStatus.queued)]);
      await tester.pumpAndSettle();

      expect(find.byKey(AppShellPage.downloadsSignalKey), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Downloads, downloading'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(tester.getTopLeft(find.text('Catalog')), catalogBefore);
      expect(tester.getTopLeft(find.text('Profile')), profileBefore);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Settings gear signals a dismissed update and About opens it directly',
    (tester) async {
      setTestWindowSize(tester, TestWindowSizes.desktop);
      final downloads = _FakeDownloadsRepository();
      final router = _shellRouter();
      final updateCubit = AppUpdateCubit(
        repository: FakeAppUpdateRepository(
          installed: const AppVersion(1, 5, 0),
          latest: testRelease(6),
        ),
        downloads: _FakeUpdateDownloads(),
      );
      addTearDown(() async {
        router.dispose();
        await updateCubit.close();
        await downloads.dispose();
      });

      await tester.pumpWidget(
        BlocProvider.value(
          value: updateCubit,
          child: IrisApp(router: router, downloadsRepository: downloads),
        ),
      );
      await tester.runAsync(updateCubit.check);
      await tester.pumpAndSettle();

      // Active strip visible -> no duplicate dot on the Settings gear.
      expect(find.byKey(UpdateNotice.noticeKey), findsOneWidget);
      expect(find.byKey(SettingsIconButton.updateSignalKey), findsNothing);

      // Put off with Later -> strip disappears, gear shows quiet green square.
      await tester.runAsync(updateCubit.dismiss);
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateNotice.noticeKey), findsNothing);
      expect(find.byKey(SettingsIconButton.updateSignalKey), findsOneWidget);

      // Navigate to the Profile branch hosting AboutAppSection and verify it
      // already surfaces the version and Update action directly.
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Version 1.6.0 available'), findsOneWidget);
      final openButton = find.byKey(AboutAppSection.openUpdateButtonKey);
      expect(
        find.descendant(of: openButton, matching: find.text('Update')),
        findsOneWidget,
      );

      await tester.tap(openButton);
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateNotice.sheetKey), findsOneWidget);

      // Closing without downloading keeps the strip hidden and the signal on.
      Navigator.of(tester.element(find.byKey(UpdateNotice.sheetKey))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateNotice.noticeKey), findsNothing);
      expect(find.byKey(SettingsIconButton.updateSignalKey), findsAtLeast(1));
    },
  );
}
