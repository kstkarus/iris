import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_download_repository.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_state.dart';
import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

import '../../helpers/test_app.dart';
import 'app_update_test_doubles.dart';

void main() {
  late List<Uri> opened;
  late bool opens;

  Future<FakeAppUpdateRepository> pumpNotice(WidgetTester tester) async {
    opened = [];
    opens = true;
    final repository = FakeAppUpdateRepository(
      latest: testRelease(3),
      installed: const AppVersion(1, 2, 0),
    );
    final cubit = AppUpdateCubit(repository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: UpdateNotice(
              open: (url) async {
                opened.add(url);
                return opens;
              },
              child: const _InsetProbe(),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Version 1.3.0 is out'), findsNothing);
    await tester.runAsync(cubit.check);
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('Download opens the build for this platform', (tester) async {
    await pumpNotice(tester);

    expect(find.text('Version 1.3.0 is out'), findsOneWidget);
    await tester.tap(find.byKey(UpdateNotice.downloadKey));
    await tester.pumpAndSettle();

    expect(opened, [testRelease(3).downloadUrl]);
    expect(find.text('Could not open the download.'), findsNothing);
  });

  testWidgets('a download nothing could open says so', (tester) async {
    await pumpNotice(tester);
    opens = false;

    await tester.tap(find.byKey(UpdateNotice.downloadKey));
    await tester.pumpAndSettle();

    expect(find.text('Could not open the download.'), findsOneWidget);
  });

  testWidgets('the strip takes the status bar inset from the page below', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 72);
    addTearDown(tester.view.resetPadding);
    await pumpNotice(tester);

    expect(_InsetProbe.topOf(tester), 0);
    expect(
      tester.getTopLeft(find.text('Version 1.3.0 is out')).dy,
      greaterThan(24),
    );

    await tester.tap(find.byKey(UpdateNotice.laterKey));
    await tester.pumpAndSettle();

    expect(_InsetProbe.topOf(tester), 24);
  });

  testWidgets('Later puts the release off', (tester) async {
    final repository = await pumpNotice(tester);

    await tester.tap(find.byKey(UpdateNotice.laterKey));
    await tester.pumpAndSettle();

    expect(find.text('Version 1.3.0 is out'), findsNothing);
    expect(repository.dismissed, const AppVersion(1, 3, 0));
  });

  testWidgets('the Android notice opens formatted release notes', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final downloads = _AndroidDownloads();
    await _pumpInAppNotice(
      tester,
      downloads,
      notes:
          'A paragraph continued\non the next line.\n\n- First change\n- Second change',
    );

    expect(find.byKey(UpdateNotice.noticeKey), findsOneWidget);
    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();

    final sheet = find.byKey(UpdateNotice.sheetKey);
    expect(
      find.descendant(of: sheet, matching: find.text('1.3.0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text("What's new")),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('A paragraph continued on the next line.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('First change')),
      findsOneWidget,
    );
    expect(find.byKey(UpdateNotice.downloadActionKey), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('Windows can cancel a download after scrolling release notes', (
    tester,
  ) async {
    _useDesktopSize(tester);
    final notes = List.generate(
      40,
      (index) => '- Change ${index + 1}: a long release note for scrolling.',
    ).join('\n');
    final cubit = await _pumpInAppNotice(
      tester,
      _AndroidDownloads(),
      platform: TargetPlatform.windows,
      notes: notes,
    );

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();

    final notesScroll = find.byKey(UpdateNotice.notesScrollKey);
    const firstNote = 'Change 1: a long release note for scrolling.';
    final noteTop = tester.getTopLeft(find.text(firstNote)).dy;

    await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.downloading);

    await tester.drag(notesScroll, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text(firstNote)).dy, lessThan(noteTop));

    await tester.tap(find.byKey(UpdateNotice.cancelDownloadKey));
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.available);
  });

  testWidgets('Windows Later closes without dismissing an available update', (
    tester,
  ) async {
    _useDesktopSize(tester);
    final cubit = await _pumpInAppNotice(
      tester,
      _AndroidDownloads(),
      platform: TargetPlatform.windows,
    );

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    final later = find.byKey(UpdateNotice.laterKey);

    await tester.tap(later);
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.available);
    expect(cubit.state.release, isNotNull);
    expect(find.byKey(UpdateNotice.sheetKey), findsNothing);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateNotice.downloadActionKey), findsOneWidget);
  });

  testWidgets('Windows Hide keeps an active download and can reopen it', (
    tester,
  ) async {
    _useDesktopSize(tester);
    final downloads = _AndroidDownloads();
    final cubit = await _pumpInAppNotice(
      tester,
      downloads,
      platform: TargetPlatform.windows,
    );

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.downloading);
    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('42 B / 100 B'), findsOneWidget);

    await tester.tap(find.byKey(UpdateNotice.hideKey));
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.downloading);
    expect(downloads.cancelCalls, 0);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    expect(find.text('42 B / 100 B'), findsOneWidget);
    await tester.tap(find.byKey(UpdateNotice.cancelDownloadKey));
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.available);
  });

  testWidgets('Windows Later preserves a ready update and can reopen it', (
    tester,
  ) async {
    _useDesktopSize(tester);
    final cubit = await _pumpInAppNotice(
      tester,
      _AndroidDownloads(restorePath: r'C:\updates\iris.exe'),
      platform: TargetPlatform.windows,
    );
    expect(cubit.state.phase, AppUpdatePhase.ready);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    final later = find.byKey(UpdateNotice.laterKey);
    expect(find.text('Restart and update'), findsOneWidget);

    await tester.tap(later);
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.ready);
    expect(find.byKey(UpdateNotice.sheetKey), findsNothing);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateNotice.installKey), findsOneWidget);
  });

  testWidgets('Windows Restart and update starts installation', (tester) async {
    _useDesktopSize(tester);
    final downloads = _AndroidDownloads(restorePath: r'C:\updates\iris.exe');
    final cubit = await _pumpInAppNotice(
      tester,
      downloads,
      platform: TargetPlatform.windows,
    );

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UpdateNotice.installKey));
    await tester.pumpAndSettle();

    expect(downloads.installCalls, 1);
    expect(cubit.state.phase, AppUpdatePhase.ready);
  });

  testWidgets('Windows 200% text keeps every phase inside the window', (
    tester,
  ) async {
    const size = Size(720, 600);
    _useDesktopSize(tester, size: size);
    final downloads = _AndroidDownloads();
    final cubit = await _pumpInAppNotice(
      tester,
      downloads,
      platform: TargetPlatform.windows,
      textScale: 2,
    );

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    _expectOnScreen(tester, find.byKey(UpdateNotice.downloadActionKey), size);
    _expectOnScreen(tester, find.byKey(UpdateNotice.laterKey), size);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.downloading);
    _expectOnScreen(tester, find.byKey(UpdateNotice.cancelDownloadKey), size);
    _expectOnScreen(tester, find.byKey(UpdateNotice.hideKey), size);
    expect(tester.takeException(), isNull);

    downloads.completeDownload(r'C:\updates\iris.exe');
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.ready);
    _expectOnScreen(tester, find.byKey(UpdateNotice.installKey), size);
    _expectOnScreen(tester, find.byKey(UpdateNotice.laterKey), size);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows narrow Russian layout fits 200% update actions', (
    tester,
  ) async {
    const size = Size(320, 640);
    _useDesktopSize(tester, size: size);
    final downloads = _AndroidDownloads();
    final cubit = await _pumpInAppNotice(
      tester,
      downloads,
      platform: TargetPlatform.windows,
      textScale: 2,
      locale: const Locale('ru'),
    );

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    _expectOnScreen(tester, find.byKey(UpdateNotice.downloadActionKey), size);
    _expectOnScreen(tester, find.byKey(UpdateNotice.laterKey), size);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.downloading);
    _expectOnScreen(tester, find.byKey(UpdateNotice.cancelDownloadKey), size);
    _expectOnScreen(tester, find.byKey(UpdateNotice.hideKey), size);
    expect(tester.takeException(), isNull);

    downloads.emitProgress(100, 100);
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.verifying);
    _expectOnScreen(tester, find.byKey(UpdateNotice.cancelDownloadKey), size);
    _expectOnScreen(tester, find.byKey(UpdateNotice.hideKey), size);
    expect(tester.takeException(), isNull);

    downloads.completeDownload(r'C:\updates\iris.exe');
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.ready);
    _expectOnScreen(tester, find.byKey(UpdateNotice.installKey), size);
    _expectOnScreen(tester, find.byKey(UpdateNotice.laterKey), size);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows scrolls release notes up to show a new failure', (
    tester,
  ) async {
    _useDesktopSize(tester);
    final downloads = _AndroidDownloads();
    final notes = List.generate(
      40,
      (index) => '- Change ${index + 1}: a long release note for scrolling.',
    ).join('\n');
    final cubit = await _pumpInAppNotice(
      tester,
      downloads,
      platform: TargetPlatform.windows,
      notes: notes,
    );

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(UpdateNotice.notesScrollKey),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Change 1: a long release note for scrolling.').hitTestable(),
      findsNothing,
    );

    await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
    await tester.pump();
    downloads.failDownload();
    await tester.pumpAndSettle();

    expect(cubit.state.phase, AppUpdatePhase.failed);
    expect(
      find
          .text(
            "Couldn't download the update. Check your connection and try again.",
          )
          .hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Windows reveals repeated installation failures after scrolling',
    (tester) async {
      _useDesktopSize(tester);
      final downloads = _AndroidDownloads(restorePath: r'C:\updates\iris.exe')
        ..failInstall = true;
      final cubit = await _pumpInAppNotice(
        tester,
        downloads,
        platform: TargetPlatform.windows,
        notes: List.generate(
          40,
          (index) =>
              '- Change ${index + 1}: a long release note for scrolling.',
        ).join('\n'),
      );

      await tester.tap(find.byKey(UpdateNotice.noticeKey));
      await tester.pumpAndSettle();
      for (var attempt = 1; attempt <= 2; attempt++) {
        await tester.drag(
          find.byKey(UpdateNotice.notesScrollKey),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        expect(
          find
              .text('Change 1: a long release note for scrolling.')
              .hitTestable(),
          findsNothing,
        );

        await tester.tap(find.byKey(UpdateNotice.installKey));
        await tester.pumpAndSettle();

        expect(downloads.installCalls, attempt);
        expect(cubit.state.failure, AppUpdateFailureKind.install);
        expect(
          find.text("Couldn't open the installer. Try again.").hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('closing and reopening the sheet keeps an active download', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final downloads = _AndroidDownloads();
    final cubit = await _pumpInAppNotice(tester, downloads);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.downloading);
    expect(
      find.descendant(
        of: find.byKey(UpdateNotice.sheetKey),
        matching: find.text('42 B / 100 B · 42%', findRichText: true),
      ),
      findsOneWidget,
    );

    downloads.emitProgress(60, 100);
    await tester.pumpAndSettle();
    expect(cubit.state.receivedBytes, 60);
    expect(
      find.descendant(
        of: find.byKey(UpdateNotice.sheetKey),
        matching: find.text('60 B / 100 B · 60%', findRichText: true),
      ),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.byKey(UpdateNotice.sheetKey))).pop();
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.downloading);
    expect(downloads.cancelCalls, 0);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    expect(find.text('Updating · 60%', findRichText: true), findsOneWidget);

    downloads.emitProgress(100, 100);
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.verifying);
    final sheet = find.byKey(UpdateNotice.sheetKey);
    expect(
      find.descendant(of: sheet, matching: find.text('Checking file')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(UpdateNotice.cancelDownloadKey));
    await tester.pumpAndSettle();
    expect(downloads.cancelCalls, 1);
    expect(cubit.state.phase, AppUpdatePhase.available);
  });

  testWidgets('a restored update stays installable after an install error', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final downloads = _AndroidDownloads(restorePath: '/tmp/iris.apk')
      ..failInstall = true;
    final cubit = await _pumpInAppNotice(tester, downloads);
    expect(cubit.state.phase, AppUpdatePhase.ready);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    expect(find.text('Install update'), findsOneWidget);

    await tester.tap(find.byKey(UpdateNotice.installKey));
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.ready);
    expect(
      find.text("Couldn't open the installer. Try again."),
      findsOneWidget,
    );
    expect(find.text('Install update'), findsOneWidget);
  });

  testWidgets(
    'large-text download keeps progress readable and cancel reachable',
    (tester) async {
      _usePhoneSize(tester, size: const Size(320, 640));
      final downloads = _AndroidDownloads();
      final cubit = await _pumpInAppNotice(
        tester,
        downloads,
        textScale: 1.6,
        reducedMotion: true,
      );
      await tester.tap(find.byKey(UpdateNotice.noticeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
      await tester.pumpAndSettle();

      final sheet = find.byKey(UpdateNotice.sheetKey);
      final paragraphs = tester.renderObjectList<RenderParagraph>(
        find.descendant(of: sheet, matching: find.byType(RichText)),
      );
      expect(
        paragraphs.where((paragraph) => paragraph.didExceedMaxLines),
        isEmpty,
      );
      final cancel = find.byKey(UpdateNotice.cancelDownloadKey);
      expect(cancel, findsOneWidget);
      final cancelRect = tester.getRect(cancel);
      expect(cancelRect.height, greaterThanOrEqualTo(44));
      expect(cancelRect.bottom, lessThanOrEqualTo(640));

      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(cubit.state.phase, AppUpdatePhase.available);
    },
  );
}

void _usePhoneSize(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<AppUpdateCubit> _pumpInAppNotice(
  WidgetTester tester,
  _AndroidDownloads downloads, {
  String notes = '## Improvements\n\n- More stable playback.',
  double textScale = 1,
  bool reducedMotion = false,
  TargetPlatform platform = TargetPlatform.android,
  Locale? locale,
}) async {
  final cubit = AppUpdateCubit(
    repository: FakeAppUpdateRepository(
      latest: AppRelease(
        version: const AppVersion(1, 3, 0),
        downloadUrl: Uri.parse('https://example.org/iris-1.3.0.apk'),
        notes: notes,
        sizeBytes: 2 * 1024 * 1024,
      ),
      installed: const AppVersion(1, 2, 0),
    ),
    downloads: downloads,
  );
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: BlocProvider.value(
          value: cubit,
          child: const UpdateNotice(child: _InsetProbe()),
        ),
      ),
    ),
  );
  await tester.runAsync(cubit.check);
  await tester.pumpAndSettle();
  return cubit;
}

class _AndroidDownloads implements AppUpdateDownloadRepository {
  _AndroidDownloads({this.restorePath});

  final String? restorePath;
  bool failInstall = false;
  bool canInstallResult = true;
  int cancelCalls = 0;
  int installCalls = 0;
  void Function(int received, int total)? _onProgress;
  Completer<String>? _download;

  void emitProgress(int received, int total) =>
      _onProgress?.call(received, total);

  void completeDownload(String path) => _download!.complete(path);

  void failDownload() => _download!.completeError(
    const AppUpdateFailure(AppUpdateFailureKind.network),
  );

  @override
  Future<String?> restore(AppRelease release) async => restorePath;

  @override
  Future<String> download(
    AppRelease release, {
    required void Function(int received, int total) onProgress,
  }) {
    _onProgress = onProgress;
    onProgress(42, 100);
    _download = Completer<String>();
    return _download!.future;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    if (_download case final download? when !download.isCompleted) {
      download.completeError(
        const AppUpdateFailure(AppUpdateFailureKind.cancelled),
      );
    }
  }

  @override
  Future<bool> canInstall() async => canInstallResult;

  @override
  Future<void> openInstallPermissionSettings() async {}

  @override
  Future<void> install(String path) async {
    installCalls++;
    if (failInstall) {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }
  }
}

void _expectOnScreen(WidgetTester tester, Finder target, Size size) {
  final rect = tester.getRect(target);
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
}

void _useDesktopSize(WidgetTester tester, {Size size = const Size(1100, 800)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Shows the top inset the page under the strip is given.
class _InsetProbe extends StatelessWidget {
  const _InsetProbe();

  static double topOf(WidgetTester tester) =>
      MediaQuery.paddingOf(tester.element(find.byType(_InsetProbe))).top;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
