import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_download_repository.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_state.dart';
import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_noise.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

import '../../helpers/test_app.dart';
import 'app_update_test_doubles.dart';

void main() {
  late List<Uri> opened;
  late bool opens;

  Future<(FakeAppUpdateRepository, AppUpdateCubit)> pumpNotice(
    WidgetTester tester, {
    AppRelease? release,
    TargetPlatform? platform,
  }) async {
    opened = [];
    opens = true;
    final repository = FakeAppUpdateRepository(
      latest: release ?? testRelease(3),
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
        theme: platform == null ? null : ThemeData(platform: platform),
      ),
    );
    expect(find.text('Version 1.3.0 available'), findsNothing);
    await tester.runAsync(cubit.check);
    await tester.pumpAndSettle();
    return (repository, cubit);
  }

  testWidgets('Download opens the build for this platform from the sheet', (
    tester,
  ) async {
    await pumpNotice(tester);

    expect(find.text('Version 1.3.0 available'), findsOneWidget);
    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateNotice.sheetKey), findsOneWidget);

    await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
    await tester.pumpAndSettle();

    expect(opened, [testRelease(3).downloadUrl]);
    expect(find.text('Could not open the download.'), findsNothing);
  });

  testWidgets('iOS notice opens release notes sheet and launches the IPA URL', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final ipaRelease = AppRelease(
      version: const AppVersion(1, 3, 0),
      downloadUrl: Uri.parse('https://example.org/iris-1.3.0-ios-unsigned.ipa'),
      notes: '## iOS\n\n- Check for updates in app.',
      sizeBytes: 31 * 1024 * 1024,
      assetName: 'iris-1.3.0-ios-unsigned.ipa',
    );
    await pumpNotice(tester, release: ipaRelease, platform: TargetPlatform.iOS);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();

    final sheet = find.byKey(UpdateNotice.sheetKey);
    expect(sheet, findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('1.3.0')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Check for updates in app.'),
      ),
      findsOneWidget,
    );
    final download = find.byKey(UpdateNotice.downloadActionKey);
    expect(
      find.descendant(of: download, matching: find.textContaining('31 MB')),
      findsOneWidget,
    );

    await tester.tap(download);
    await tester.pumpAndSettle();
    expect(opened, [ipaRelease.downloadUrl]);
    expect(find.text('Could not open the download.'), findsNothing);
  });

  testWidgets('a download nothing could open says so inside the sheet', (
    tester,
  ) async {
    await pumpNotice(tester);
    opens = false;

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UpdateNotice.downloadActionKey));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(UpdateNotice.footerKey),
        matching: find.text('Could not open the download.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the strip takes the status bar inset from the page below', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 72);
    addTearDown(tester.view.resetPadding);
    await pumpNotice(tester);

    expect(_InsetProbe.topOf(tester), 0);
    expect(
      tester.getTopLeft(find.text('Version 1.3.0 available')).dy,
      greaterThan(24),
    );

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UpdateNotice.laterKey));
    await tester.pumpAndSettle();

    expect(_InsetProbe.topOf(tester), 24);
  });

  testWidgets('Later puts the release off', (tester) async {
    final (repository, _) = await pumpNotice(tester);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UpdateNotice.laterKey));
    await tester.pumpAndSettle();

    expect(find.byKey(UpdateNotice.sheetKey), findsNothing);
    expect(find.text('Version 1.3.0 available'), findsNothing);
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
          'A paragraph continued\non the next line.\n\n'
          '- First change\n\n### Playback\n1. Choose a track\n2. Resume',
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
    expect(
      find.descendant(of: sheet, matching: find.text('•')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('1.')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('2.')),
      findsOneWidget,
    );
    expect(find.byKey(UpdateNotice.downloadActionKey), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets(
    'an open update follows the version, notes and size of a new release',
    (tester) async {
      _usePhoneSize(tester);
      final repository = FakeAppUpdateRepository(
        latest: testRelease(3),
        installed: const AppVersion(1, 2, 0),
      );
      final cubit = await _pumpInAppNotice(
        tester,
        _AndroidDownloads(),
        repository: repository,
      );
      await tester.tap(find.byKey(UpdateNotice.noticeKey));
      await tester.pumpAndSettle();

      repository.latest = AppRelease(
        version: const AppVersion(1, 4, 0),
        downloadUrl: testRelease(4).downloadUrl,
        sizeBytes: 42 * 1024 * 1024,
        notes: 'New release notes',
      );
      await cubit.checkManually();
      await tester.pumpAndSettle();

      final sheet = find.byKey(UpdateNotice.sheetKey);
      expect(
        find.descendant(of: sheet, matching: find.text('1.4.0')),
        findsOneWidget,
      );
      expect(find.text('New release notes'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(UpdateNotice.downloadActionKey),
          matching: find.textContaining('42 MB'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Windows disables Cancel while cancellation finishes', (
    tester,
  ) async {
    _useDesktopSize(tester);
    final notes = List.generate(
      40,
      (index) => '- Change ${index + 1}: a long release note for scrolling.',
    ).join('\n');
    final cancelGate = Completer<void>();
    final downloads = _AndroidDownloads()..cancelGate = cancelGate;
    final cubit = await _pumpInAppNotice(
      tester,
      downloads,
      platform: TargetPlatform.windows,
      notes: notes,
    );
    addTearDown(() {
      if (!cancelGate.isCompleted) cancelGate.complete();
    });

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

    final cancel = find.byKey(UpdateNotice.cancelDownloadKey);
    await tester.tap(cancel);
    await tester.pump();
    expect(tester.widget<TextButton>(cancel).onPressed, isNull);
    expect(
      find.descendant(of: cancel, matching: find.byType(PixelNoise)),
      findsWidgets,
    );
    await tester.tap(cancel);
    expect(downloads.cancelCalls, 1);
    expect(cubit.state.cancelling, isTrue);
    cancelGate.complete();
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.available);
    expect(cubit.state.cancelling, isFalse);
    expect(
      find.byKey(UpdateNotice.downloadActionKey).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets(
    'Windows Later dismisses the offered release and hides the strip',
    (tester) async {
      _useDesktopSize(tester);
      final repository = FakeAppUpdateRepository(
        latest: testRelease(3),
        installed: const AppVersion(1, 2, 0),
      );
      final cubit = await _pumpInAppNotice(
        tester,
        _AndroidDownloads(),
        platform: TargetPlatform.windows,
        repository: repository,
      );

      await tester.tap(find.byKey(UpdateNotice.noticeKey));
      await tester.pumpAndSettle();
      final later = find.byKey(UpdateNotice.laterKey);

      await tester.tap(later);
      await tester.pumpAndSettle();
      expect(cubit.state.release, isNull);
      expect(repository.dismissed, const AppVersion(1, 3, 0));
      expect(find.byKey(UpdateNotice.sheetKey), findsNothing);
      expect(find.byKey(UpdateNotice.noticeKey), findsNothing);

      await cubit.checkManually();
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateNotice.noticeKey), findsOneWidget);
    },
  );

  testWidgets('close, Escape and backdrop keep a Windows download running', (
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
    final progress = find.text('Downloading · 42 B / 100 B');
    expect(progress, findsOneWidget);
    for (final close in [
      () => tester.tap(find.byType(CloseButton)),
      () => tester.sendKeyEvent(LogicalKeyboardKey.escape),
      () => tester.tapAt(const Offset(20, 20)),
    ]) {
      await close();
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateNotice.sheetKey), findsNothing);
      expect(cubit.state.phase, AppUpdatePhase.downloading);
      expect(downloads.cancelCalls, 0);

      await tester.tap(find.byKey(UpdateNotice.noticeKey));
      await tester.pumpAndSettle();
      expect(progress, findsOneWidget);
    }
    await tester.tap(find.byKey(UpdateNotice.cancelDownloadKey));
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.available);
  });

  testWidgets('Windows Close preserves a ready update for reopening', (
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
    expect(find.text('Restart and update'), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
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
    _expectOnScreen(tester, find.byType(CloseButton), size);
    expect(tester.takeException(), isNull);

    downloads.completeDownload(r'C:\updates\iris.exe');
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.ready);
    _expectOnScreen(tester, find.byKey(UpdateNotice.installKey), size);
    _expectOnScreen(tester, find.byType(CloseButton), size);
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
    _expectOnScreen(tester, find.byType(CloseButton), size);
    expect(tester.takeException(), isNull);

    downloads.emitProgress(100, 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(cubit.state.phase, AppUpdatePhase.verifying);
    expect(find.byKey(UpdateNotice.cancelDownloadKey), findsNothing);
    final bar = find.byType(SegmentedBar);
    expect(tester.widget<SegmentedBar>(bar).value, 1);
    _expectOnScreen(tester, bar, size);
    _expectOnScreen(tester, find.byType(CloseButton).hitTestable(), size);
    expect(tester.takeException(), isNull);

    downloads.completeDownload(r'C:\updates\iris.exe');
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.ready);
    _expectOnScreen(tester, find.byKey(UpdateNotice.installKey), size);
    _expectOnScreen(tester, find.byType(CloseButton), size);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Windows shows file damage and retry without scrolling the notes',
    (tester) async {
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
      downloads.failDownload(AppUpdateFailureKind.invalidFile);
      await tester.pumpAndSettle();

      expect(cubit.state.phase, AppUpdatePhase.failed);
      final footer = find.byKey(UpdateNotice.footerKey);
      expect(
        find
            .descendant(of: footer, matching: find.text('File damaged'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Download again').hitTestable(), findsOneWidget);
      expect(
        find.text('Change 1: a long release note for scrolling.').hitTestable(),
        findsNothing,
      );
      await tester.tap(find.byKey(UpdateNotice.laterKey));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateNotice.noticeKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
          find.text("Couldn't open the installer.").hitTestable(),
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
        matching: find.textContaining(
          RegExp(r'42 B / 100 B.*42%'),
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );

    downloads.emitProgress(60, 100);
    await tester.pumpAndSettle();
    expect(cubit.state.receivedBytes, 60);
    expect(
      find.descendant(
        of: find.byKey(UpdateNotice.sheetKey),
        matching: find.textContaining(
          RegExp(r'60 B / 100 B.*60%'),
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );

    Navigator.of(tester.element(find.byKey(UpdateNotice.sheetKey))).pop();
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.downloading);
    expect(downloads.cancelCalls, 0);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    expect(find.text('Downloading 1.3.0 · 60%'), findsOneWidget);

    final bar = find.byType(SegmentedBar);
    final downloadingBar = tester.element(bar);
    final leading = tester.getTopLeft(bar);
    downloads.emitProgress(100, 100);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(cubit.state.phase, AppUpdatePhase.verifying);
    final sheet = find.byKey(UpdateNotice.sheetKey);
    expect(
      find.descendant(of: sheet, matching: find.text('Verifying file')),
      findsOneWidget,
    );
    expect(find.byKey(UpdateNotice.cancelDownloadKey), findsNothing);
    expect(tester.widget<SegmentedBar>(bar).value, 1);
    expect(tester.element(bar), same(downloadingBar));
    expect(tester.getTopLeft(bar), leading);
  });

  testWidgets('a restored update stays installable after an install error', (
    tester,
  ) async {
    _usePhoneSize(tester);
    final install = Completer<void>();
    final downloads = _AndroidDownloads(restorePath: '/tmp/iris.apk')
      ..installGate = install
      ..failInstall = true;
    final cubit = await _pumpInAppNotice(tester, downloads);
    expect(cubit.state.phase, AppUpdatePhase.ready);

    await tester.tap(find.byKey(UpdateNotice.noticeKey));
    await tester.pumpAndSettle();
    expect(find.text('Install'), findsOneWidget);

    await tester.tap(find.byKey(UpdateNotice.installKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final sheet = find.byKey(UpdateNotice.sheetKey);
    expect(cubit.state.phase, AppUpdatePhase.installing);
    expect(
      find.descendant(
        of: sheet,
        matching: find.bySemanticsLabel('Opening installer'),
      ),
      findsOneWidget,
    );
    install.complete();
    await tester.pumpAndSettle();
    expect(cubit.state.phase, AppUpdatePhase.ready);
    expect(find.text("Couldn't open the installer."), findsOneWidget);
    expect(find.text('Retry install'), findsOneWidget);
  });

  testWidgets(
    'missing Android permission keeps Install visible and reports the error',
    (tester) async {
      _usePhoneSize(tester);
      final permission = Completer<bool>();
      final downloads = _AndroidDownloads(restorePath: '/tmp/iris.apk')
        ..permissionGate = permission;
      final cubit = await _pumpInAppNotice(
        tester,
        downloads,
        notes: List.generate(
          40,
          (index) => '- Release note ${index + 1}',
        ).join('\n'),
      );
      await tester.tap(find.byKey(UpdateNotice.noticeKey));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(UpdateNotice.notesScrollKey),
        const Offset(0, -420),
      );
      await tester.pumpAndSettle();
      final install = find.byKey(UpdateNotice.installKey);
      await tester.tap(install);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(install.hitTestable(), findsOneWidget);
      expect(find.text('Opening installer'), findsNothing);

      permission.complete(false);
      await tester.pumpAndSettle();
      expect(cubit.state.failure, AppUpdateFailureKind.permission);
      expect(downloads.permissionSettingsOpened, 1);
      expect(downloads.installCalls, 0);
      expect(
        find
            .text('Allow Iris to install apps in Android settings.')
            .hitTestable(),
        findsOneWidget,
      );
      expect(find.text('Release note 1').hitTestable(), findsNothing);
      Navigator.of(tester.element(find.byKey(UpdateNotice.sheetKey))).pop();
      await tester.pumpAndSettle();
      final status = find.text('Permission needed');
      expect(status.hitTestable(), findsOneWidget);
      expect(
        tester.widget<Text>(status).textSpan?.style?.color,
        Theme.of(tester.element(status)).colorScheme.error,
      );
    },
  );

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

  testWidgets('Later dismisses the update notice snappily within 240ms', (
    tester,
  ) async {
    final (_, cubit) = await pumpNotice(tester);

    await cubit.dismiss();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Version 1.3.0 available'), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets(
    'Windows sheet smooths failure appearance and footer transitions',
    (tester) async {
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
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump();
      expect(cubit.state.phase, AppUpdatePhase.downloading);
      expect(find.byKey(UpdateNotice.cancelDownloadKey), findsOneWidget);

      downloads.failDownload();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpAndSettle();
      expect(
        find.text("Couldn't download the update. Check your connection."),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isFalse);
    },
  );

  testWidgets(
    'strip keeps live download bytes static and hides tap affordance while installing',
    (tester) async {
      _usePhoneSize(tester);
      final install = Completer<void>();
      final downloads = _AndroidDownloads(initialProgress: false)
        ..installGate = install;
      final cubit = await _pumpInAppNotice(
        tester,
        downloads,
        repository: FakeAppUpdateRepository(
          latest: AppRelease(
            version: const AppVersion(1, 3, 0),
            downloadUrl: Uri.parse('https://example.org/iris-1.3.0.apk'),
            notes: '## Improvements\n\n- More stable playback.',
          ),
          installed: const AppVersion(1, 2, 0),
        ),
      );

      final notice = find.byKey(UpdateNotice.noticeKey);
      final downloadFuture = cubit.download();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.descendant(of: notice, matching: find.byType(PixelNoise)),
        findsOneWidget,
      );

      downloads.emitProgress(12 * 1024 * 1024, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.textContaining('12.0 MB', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.descendant(of: notice, matching: find.byType(PixelNoise)),
        findsNothing,
      );

      downloads.emitProgress(100, 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.descendant(of: notice, matching: find.byType(PixelNoise)),
        findsOneWidget,
      );
      expect(tester.widget<InkWell>(notice).onTap, isNotNull);
      expect(
        find.descendant(of: notice, matching: find.byType(PixelIcon)),
        findsOneWidget,
      );

      downloads.completeDownload('/tmp/iris.apk');
      await downloadFuture;
      await tester.pumpAndSettle();

      final installing = cubit.install();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(cubit.state.phase, AppUpdatePhase.installing);
      expect(
        find.descendant(of: notice, matching: find.byType(PixelNoise)),
        findsOneWidget,
      );
      expect(tester.widget<InkWell>(notice).onTap, isNull);
      expect(
        find.descendant(of: notice, matching: find.byType(PixelIcon)),
        findsNothing,
      );

      install.complete();
      await installing;
      await tester.pumpAndSettle();
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
  FakeAppUpdateRepository? repository,
}) async {
  final cubit = AppUpdateCubit(
    repository:
        repository ??
        FakeAppUpdateRepository(
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
  _AndroidDownloads({this.restorePath, this.initialProgress = true});

  final String? restorePath;
  final bool initialProgress;
  Completer<void>? installGate;
  Completer<void>? cancelGate;
  Completer<bool>? permissionGate;
  bool failInstall = false;
  bool canInstallResult = true;
  int cancelCalls = 0;
  int installCalls = 0;
  int permissionSettingsOpened = 0;
  void Function(int received, int total)? _onProgress;
  Completer<String>? _download;

  void emitProgress(int received, int total) =>
      _onProgress?.call(received, total);

  void completeDownload(String path) => _download!.complete(path);

  void failDownload([
    AppUpdateFailureKind kind = AppUpdateFailureKind.network,
  ]) => _download!.completeError(AppUpdateFailure(kind));

  @override
  Future<String?> restore(AppRelease release) async => restorePath;

  @override
  Future<String> download(
    AppRelease release, {
    required void Function(int received, int total) onProgress,
  }) {
    _onProgress = onProgress;
    if (initialProgress) onProgress(42, 100);
    _download = Completer<String>();
    return _download!.future;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    if (cancelGate case final gate?) {
      cancelGate = null;
      await gate.future;
    }
    if (_download case final download? when !download.isCompleted) {
      download.completeError(
        const AppUpdateFailure(AppUpdateFailureKind.cancelled),
      );
    }
  }

  @override
  Future<bool> canInstall() async {
    if (permissionGate case final gate?) return gate.future;
    return canInstallResult;
  }

  @override
  Future<void> openInstallPermissionSettings() async =>
      permissionSettingsOpened++;

  @override
  Future<void> install(String path) async {
    installCalls++;
    await installGate?.future;
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
