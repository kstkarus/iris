import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/widgets/download_manager_view.dart';
import 'package:iris/shared/widgets/focusable_list_row.dart';

import 'package:flutter/rendering.dart';
import 'package:iris/features/downloads/presentation/widgets/download_queue.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';

void main() {
  for (final fails in [false, true]) {
    testWidgets(
      'confirmed queue deletion survives a removed row (failure: $fails)',
      (tester) async {
        setTestWindowSize(tester, const Size(390, 844));
        final active = _item('active', 1, DownloadStatus.downloading);
        final next = _item('next', 2, DownloadStatus.queued);
        final repository = _Downloads([active, next]);
        if (fails) repository.failed.add(active.id);
        final manager = DownloadManagerCubit(repository: repository)..load();
        addTearDown(() {
          unawaited(manager.close());
          unawaited(repository.changes.close());
        });
        await tester.pumpWidget(
          testApp(
            BlocProvider.value(
              value: manager,
              child: Scaffold(body: DownloadQueueView(onFiles: () {})),
            ),
            theme: buildAppTheme(),
          ),
        );
        await tester.pumpAndSettle();
        final rowContext = tester.element(find.byKey(const ValueKey('active')));
        await tester.tap(find.byKey(const ValueKey('queue_menu_active')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('queue_delete_active')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('download_delete_confirmation')),
          findsOneWidget,
        );
        repository.items = [_item('active', 1, DownloadStatus.completed), next];
        repository.changes.add(List.of(repository.items));
        await tester.pumpAndSettle();
        expect(rowContext.mounted, isFalse);
        expect(manager.isClosed, isFalse);
        await tester.tap(find.byKey(const Key('download_delete_confirm')));
        await tester.pumpAndSettle();
        expect(repository.deleted, ['active']);
        expect(repository.items.any((item) => item.id == active.id), fails);
        expect(find.byType(SnackBar), fails ? findsOneWidget : findsNothing);
      },
    );
  }
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'selection toolbar stays readable and usable at width $width with large text',
      (tester) async {
        final mono = FontLoader('Medeo Mono')
          ..addFont(rootBundle.load('assets/fonts/MedeoMono-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/MedeoMono-Medium.ttf'))
          ..addFont(rootBundle.load('assets/fonts/MedeoMono-SemiBold.ttf'));
        final sans = FontLoader('Medeo Sans')
          ..addFont(rootBundle.load('assets/fonts/MedeoSans-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/MedeoSans-Medium.ttf'));
        await Future.wait([mono.load(), sans.load()]);
        setTestWindowSize(tester, Size(width, 844));
        final repository = _Downloads([
          _item('one', 1, DownloadStatus.completed),
          _item('two', 2, DownloadStatus.completed),
        ]);
        final manager = DownloadManagerCubit(repository: repository)..load();
        addTearDown(() {
          unawaited(manager.close());
          unawaited(repository.changes.close());
        });
        await tester.pumpWidget(
          testApp(
            BlocProvider.value(
              value: manager,
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: Scaffold(
                    body: SafeArea(
                      child: PageFrame(
                        child: DownloadManagerView(
                          titleKey: 'anime:1',
                          onWatch: (_) {},
                          onOpenTitle: (_) {},
                          onBrowseCatalog: () {},
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            theme: buildAppTheme(),
            locale: const Locale('ru'),
          ),
        );
        await tester.pumpAndSettle();
        await _select(tester);
        await tester.pumpAndSettle();
        final label = find.text('Выбрать все');
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
          maxLines: paragraph.maxLines,
          locale: paragraph.locale,
          strutStyle: paragraph.strutStyle,
          textWidthBasis: paragraph.textWidthBasis,
          textHeightBehavior: paragraph.textHeightBehavior,
        )..layout(maxWidth: paragraph.size.width);
        expect(painter.height, lessThanOrEqualTo(paragraph.size.height));
        painter.dispose();
        await tester.tap(find.byKey(const Key('download_delete_all')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('download_delete_selected')),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.byKey(const Key('download_delete_cancel')));
        await tester.pumpAndSettle();
        expect(repository.deleted, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (platform, lastFile) in [
    (TargetPlatform.android, true),
    (TargetPlatform.windows, true),
    (TargetPlatform.windows, false),
  ]) {
    final phone = platform == TargetPlatform.android;
    testWidgets(
      'deleting a file updates its title on $platform (last file: $lastFile)',
      _onPlatform(platform, (tester) async {
        setTestWindowSize(
          tester,
          phone ? const Size(390, 844) : const Size(1440, 900),
        );
        final repository = _Downloads([
          _item('gone', 1, DownloadStatus.queued),
          if (!lastFile) _item('kept', 2, DownloadStatus.completed),
        ]);
        final manager = DownloadManagerCubit(repository: repository)..load();
        addTearDown(() {
          unawaited(manager.close());
          unawaited(repository.changes.close());
        });
        var titleDeleted = 0;
        await tester.pumpWidget(
          testApp(
            BlocProvider.value(
              value: manager,
              child: Scaffold(
                body: DownloadManagerView(
                  titleKey: phone ? 'anime:1' : null,
                  onWatch: (_) {},
                  onOpenTitle: (_) {},
                  onBrowseCatalog: () {},
                  onTitleDeleted: () {
                    titleDeleted++;
                    return false;
                  },
                ),
              ),
            ),
            theme: buildAppTheme(),
          ),
        );
        await tester.pumpAndSettle();
        await _select(tester);
        await tester.pumpAndSettle();
        await tester.tap(_row('gone'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('download_delete_selected')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('download_delete_confirm')));
        await tester.pumpAndSettle();
        expect(repository.deleted, ['gone']);
        expect(
          manager.state.downloads.any((item) => item.id == 'gone'),
          isFalse,
        );
        expect(find.byKey(const ValueKey('gone')), findsNothing);
        expect(titleDeleted, phone ? 1 : 0);
        if (lastFile && !phone) {
          expect(find.text('Browse the catalog'), findsOneWidget);
        }
        if (!lastFile) {
          expect(manager.state.downloads.single.id, 'kept');
        }
        expect(tester.takeException(), isNull);
      }),
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'delete a subset and retain failures on $platform',
      _onPlatform(platform, (tester) async {
        setTestWindowSize(
          tester,
          platform == TargetPlatform.android
              ? const Size(390, 844)
              : const Size(1440, 900),
        );
        final repository = _Downloads([
          _item('a1', 1, DownloadStatus.completed),
          _item('a2', 2, DownloadStatus.downloading),
          _item('a3', 3, DownloadStatus.queued),
          _item('b1', 1, DownloadStatus.paused, source: 'b'),
          _item('b2', 2, DownloadStatus.failed, source: 'b'),
        ]);
        final manager = DownloadManagerCubit(repository: repository)..load();
        addTearDown(() {
          unawaited(manager.close());
          unawaited(repository.changes.close());
        });
        var watched = 0;
        await tester.pumpWidget(
          testApp(
            BlocProvider.value(
              value: manager,
              child: Scaffold(
                body: DownloadManagerView(
                  titleKey: 'anime:1',
                  onWatch: (_) => watched++,
                  onOpenTitle: (_) {},
                  onBrowseCatalog: () {},
                ),
              ),
            ),
            theme: buildAppTheme(),
          ),
        );
        await tester.pumpAndSettle();
        await _select(tester);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('download_delete_selected')),
              )
              .onPressed,
          isNull,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.delete);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);

        // All five statuses can be selected; a same-numbered second dub is distinct.
        for (final id in ['a1', 'a2', 'a3', 'b1', 'b2']) {
          expect(
            find.byKey(ValueKey('download_delete_check_$id')),
            findsOneWidget,
          );
        }
        await tester.tap(_row('a1'));
        await tester.pumpAndSettle();
        expect(watched, 0);
        final group = find.byKey(
          const ValueKey('download_group_select_online:anilibria/a'),
        );
        expect(tester.widget<Checkbox>(group).value, isNull);
        await tester.tap(group);
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(group).value, isTrue);
        expect(find.text('Delete 3'), findsOneWidget);

        await tester.tap(find.byKey(const Key('download_delete_selected')));
        await tester.pumpAndSettle();
        expect(find.text('Delete 3 downloads?'), findsOneWidget);
        expect(repository.deleted, isEmpty);
        await tester.tap(find.byKey(const Key('download_delete_dismiss')));
        await tester.pumpAndSettle();
        expect(find.text('Delete 3'), findsOneWidget);
        repository.failed.add('a2');
        await tester.tap(find.byKey(const Key('download_delete_selected')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('download_delete_confirm')));
        await tester.pumpAndSettle();
        expect(repository.deleted, ['a1', 'a2', 'a3']);
        expect(manager.state.downloads.map((item) => item.id), [
          'a2',
          'b1',
          'b2',
        ]);
        expect(
          tester
              .widget<Checkbox>(
                find.byKey(const ValueKey('download_delete_check_a2')),
              )
              .value,
          isTrue,
        );
        expect(find.text('Couldn’t delete 1 download.'), findsOneWidget);
        expect(find.text('Delete 1'), findsOneWidget);
        repository.failed.clear();
        await tester.tap(find.byKey(const Key('download_delete_selected')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('download_delete_confirm')));
        await tester.pumpAndSettle();
        expect(manager.state.downloads.map((item) => item.id), ['b1', 'b2']);
        expect(find.byKey(const Key('download_delete_cancel')), findsNothing);
        expect(watched, 0);
        expect(tester.takeException(), isNull);
      }),
    );
  }

  testWidgets(
    'a single unlinked file supports selection, cancel, Back and delete',
    (tester) async {
      setTestWindowSize(tester, const Size(390, 844));
      final item = _item(
        'one',
        1,
        DownloadStatus.completed,
      ).copyWith(animeId: '');
      final repository = _Downloads([item]);
      final manager = DownloadManagerCubit(repository: repository)..load();
      addTearDown(() {
        unawaited(manager.close());
        unawaited(repository.changes.close());
      });
      var titleDeleted = 0;
      await tester.pumpWidget(
        testApp(
          BlocProvider.value(
            value: manager,
            child: Scaffold(
              body: DownloadManagerView(
                titleKey: 'online:anilibria/a',
                onWatch: (_) {},
                onOpenTitle: (_) {},
                onBrowseCatalog: () {},
                onTitleDeleted: () {
                  titleDeleted++;
                  return false;
                },
              ),
            ),
          ),
          theme: buildAppTheme(),
        ),
      );
      await tester.pumpAndSettle();
      await _select(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_delete_all')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(repository.deleted, isEmpty);
      expect(find.byKey(const Key('download_delete_cancel')), findsNothing);
      await _select(tester);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(const ValueKey('download_delete_check_one')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('download_delete_all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_delete_selected')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_delete_confirm')));
      await tester.pumpAndSettle();
      expect(repository.deleted, ['one']);
      expect(titleDeleted, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Windows range selection and Delete act on selected copies',
    _onPlatform(TargetPlatform.windows, (tester) async {
      setTestWindowSize(tester, const Size(1000, 800));
      final repository = _Downloads([
        for (var index = 1; index <= 4; index++)
          _item('a$index', index, DownloadStatus.completed),
      ]);
      final manager = DownloadManagerCubit(repository: repository)..load();
      addTearDown(() {
        unawaited(manager.close());
        unawaited(repository.changes.close());
      });
      await tester.pumpWidget(
        testApp(
          BlocProvider.value(
            value: manager,
            child: Scaffold(
              body: DownloadManagerView(
                titleKey: 'anime:1',
                onWatch: (_) {},
                onOpenTitle: (_) {},
                onBrowseCatalog: () {},
              ),
            ),
          ),
          theme: buildAppTheme(),
        ),
      );
      await tester.pumpAndSettle();
      await _select(tester);
      await tester.pumpAndSettle();
      await tester.tap(_row('a1'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(_row('a3'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('Delete 3'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(find.text('Delete 3 downloads?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('download_delete_dismiss')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repository.deleted, isEmpty);
      expect(find.byKey(const Key('download_delete_cancel')), findsNothing);
      expect(tester.takeException(), isNull);
    }),
  );
}

WidgetTesterCallback _onPlatform(
  TargetPlatform platform,
  WidgetTesterCallback run,
) => (tester) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await run(tester);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
};

Finder _row(String id) => find.descendant(
  of: find.byKey(ValueKey(id)),
  matching: find.byType(FocusableListRow),
);

Future<void> _select(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('download_title_menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('download_title_select')));
  await tester.pump();
}

DownloadItem _item(
  String id,
  int episode,
  DownloadStatus status, {
  String source = 'a',
}) => DownloadItem(
  id: id,
  animeId: '1',
  animeTitle: 'Frieren',
  sourceTitle: source,
  magnet: 'online:anilibria/$source?anime=1',
  fileIndex: episode,
  fileName: '$episode «Episode»',
  relativePath: '$episode.mp4',
  localPath: '$id.mp4',
  totalBytes: 1000,
  downloadedBytes: status == DownloadStatus.completed ? 1000 : 100,
  downloadRateBytesPerSecond: 0,
  peers: 0,
  status: status,
  createdAt: DateTime(2026),
);

class _Downloads extends MockDownloadsRepository {
  _Downloads(this.items);
  List<DownloadItem> items;
  final changes = StreamController<List<DownloadItem>>.broadcast();
  final failed = <String>{};
  final deleted = <String>[];

  @override
  Stream<List<DownloadItem>> watchDownloads() async* {
    yield List.of(items);
    yield* changes.stream;
  }

  @override
  Future<bool> delete({required String id}) async {
    deleted.add(id);
    if (failed.contains(id)) return false;
    items = items.where((item) => item.id != id).toList();
    changes.add(List.of(items));
    return true;
  }
}
