import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/app.dart';
import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/domain/entities/download_queue_order.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/pages/download_manager_page.dart';
import 'package:iris/features/downloads/presentation/pages/download_queue_page.dart';
import 'package:iris/features/downloads/presentation/pages/download_title_page.dart';
import 'package:iris/features/downloads/presentation/widgets/download_manager_view.dart';

import '../../../../helpers/test_window.dart';

DownloadItem _item(String id, DownloadStatus status) => DownloadItem(
  id: id,
  animeId: '1',
  animeTitle: 'Frieren',
  sourceTitle: 'Dub · 1080p',
  magnet: 'magnet',
  fileIndex: int.tryParse(id) ?? 0,
  fileName: 'episode-$id.mkv',
  relativePath: '$id.mkv',
  localPath: '/downloads/$id.mkv',
  totalBytes: 100,
  downloadedBytes: 43,
  downloadRateBytesPerSecond: 10,
  peers: 2,
  status: status,
  createdAt: DateTime(2026),
);

class _Downloads extends MockDownloadsRepository {
  _Downloads({this.busy = false, int count = 4})
    : items = [
        _item('0', DownloadStatus.downloading),
        for (var index = 1; index <= count; index++)
          _item('$index', DownloadStatus.queued),
        _item('paused', DownloadStatus.paused),
      ];
  List<DownloadItem> items;
  final changes = StreamController<List<DownloadItem>>.broadcast();
  final bool busy;
  int activeSubscriptions = 0;
  bool failReorder = false;
  int temporary = 1024;
  int cleared = 0;
  List<String> get waiting => items
      .where((item) => item.status == DownloadStatus.queued)
      .map((item) => item.id)
      .toList();
  void emit() => changes.add(List.of(items));
  @override
  Stream<List<DownloadItem>> watchDownloads() => Stream.multi((controller) {
    activeSubscriptions++;
    controller.add(List.of(items));
    final subscription = changes.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = () async {
      activeSubscriptions--;
      await subscription.cancel();
    };
  });

  @override
  Future<void> reorderQueue({required List<String> ids}) async {
    if (failReorder) throw StateError('storage unavailable');
    items = reorderQueuedDownloads(items, ids);
    emit();
  }

  void _start() {
    if (items.any((item) => item.status == DownloadStatus.downloading) ||
        waiting.isEmpty) {
      return;
    }
    final id = waiting.first;
    items = [
      for (final item in items)
        if (item.id == id)
          item.copyWith(status: DownloadStatus.downloading)
        else
          item,
    ];
  }

  void completeCurrent() {
    items = [
      for (final item in items)
        if (item.status == DownloadStatus.downloading)
          item.copyWith(status: DownloadStatus.completed)
        else
          item,
    ];
    _start();
    emit();
  }

  @override
  Future<void> pause({required String id}) async {
    items = [
      for (final item in items)
        if (item.id == id)
          item.copyWith(status: DownloadStatus.paused)
        else
          item,
    ];
    _start();
    emit();
  }

  @override
  Future<void> resume({required String id}) async {
    final item = items.singleWhere((item) => item.id == id);
    items = [
      ...items.where((item) => item.id != id),
      item.copyWith(status: DownloadStatus.queued),
    ];
    _start();
    emit();
  }

  @override
  Future<DownloadStorageUsage> calculateStorageUsage() async =>
      DownloadStorageUsage(cacheBytes: temporary, cacheInUse: busy);
  @override
  Future<bool> clearCache() async {
    cleared++;
    if (busy) return false;
    temporary = 0;
    return true;
  }
}

Future<({DownloadManagerCubit cubit, GoRouter router})> _mount(
  WidgetTester tester,
  _Downloads repository, {
  Size size = const Size(390, 844),
}) async {
  setTestWindowSize(tester, size);
  final cubit = DownloadManagerCubit(repository: repository)..load();
  late GoRouter router;
  router = GoRouter(
    initialLocation: '/downloads',
    routes: [
      GoRoute(
        path: '/downloads',
        builder: (context, state) => BlocProvider.value(
          value: cubit,
          child: DownloadManagerPage(
            onWatch: (_) {},
            onBrowseCatalog: () {},
            onOpenTitle: (title) => router.push('/title', extra: title),
          ),
        ),
      ),
      GoRoute(
        path: '/downloads/queue',
        name: 'download-queue',
        builder: (context, state) => BlocProvider.value(
          value: cubit,
          child: DownloadQueuePage(
            onOpenTitle: (title) => router.push('/title', extra: title),
          ),
        ),
      ),
      GoRoute(
        path: '/title',
        builder: (context, state) => BlocProvider.value(
          value: cubit,
          child: DownloadTitlePage(
            title: state.extra as DownloadTitle,
            onWatch: (_) {},
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    IrisApp(
      router: router,
      downloadsRepository: repository,
      locale: const Locale('en'),
    ),
  );
  await tester.pumpAndSettle();
  return (cubit: cubit, router: router);
}

Future<void> _close(
  WidgetTester tester,
  _Downloads repository,
  ({DownloadManagerCubit cubit, GoRouter router}) harness,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  harness.router.dispose();
  await tester.runAsync(() async {
    await harness.cubit.close();
    await repository.changes.close();
  });
}

Future<void> _move(
  WidgetTester tester,
  String from,
  String target, {
  required bool down,
  required PointerDeviceKind kind,
}) async {
  final handle = find.byKey(ValueKey('queue_handle_$from'));
  final destination = tester.getRect(find.byKey(ValueKey(target)));
  final point = tester.getCenter(handle);
  final gesture = await tester.startGesture(point, kind: kind);
  await gesture.moveBy(const Offset(0, 12));
  await tester.pump(const Duration(milliseconds: 16));
  final end = down ? destination.bottom - 4 : destination.top + 4;
  for (var step = 1; step <= 16; step++) {
    await gesture.moveTo(
      Offset(point.dx, point.dy + (end - point.dy) * step / 16),
    );
    await tester.pump(const Duration(milliseconds: 24));
  }
  await tester.pump(const Duration(milliseconds: 350));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('announcements have one owner across library, title and queue', (
    tester,
  ) async {
    final announced = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final event = message as Map;
        if (event['type'] == 'announce') {
          announced.add((event['data'] as Map)['message'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => messenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        null,
      ),
    );
    final repository = _Downloads(count: 3);
    repository.items[0] = repository.items[0].copyWith(
      fileName: 'episode-04.mkv',
    );
    repository.items.addAll([
      _item('10', DownloadStatus.completed),
      _item('11', DownloadStatus.failed),
    ]);
    final harness = await _mount(tester, repository);
    expect(announced, isEmpty);
    expect(repository.activeSubscriptions, 2);

    void setStatus(String id, DownloadStatus status) {
      repository.items = [
        for (final item in repository.items)
          if (item.id == id) item.copyWith(status: status) else item,
      ];
      repository.emit();
    }

    setStatus('0', DownloadStatus.completed);
    await tester.pumpAndSettle();
    setStatus('0', DownloadStatus.completed);
    await tester.pumpAndSettle();
    expect(announced, ['Downloaded: Frieren, Episode 04']);

    final title = downloadTitles(repository.items).single;
    harness.router.push('/title', extra: title);
    await tester.pumpAndSettle();
    expect(
      find.byType(DownloadManagerView, skipOffstage: false),
      findsNWidgets(2),
    );
    setStatus('1', DownloadStatus.failed);
    await tester.pumpAndSettle();
    expect(announced, [
      'Downloaded: Frieren, Episode 04',
      'Download failed: Frieren, Episode 01',
    ]);

    harness.router.push('/downloads/queue');
    await tester.pumpAndSettle();
    setStatus('2', DownloadStatus.completed);
    await tester.pumpAndSettle();
    expect(announced, [
      'Downloaded: Frieren, Episode 04',
      'Download failed: Frieren, Episode 01',
      'Downloaded: Frieren, Episode 02',
    ]);

    final replacement = _Downloads(count: 1);
    replacement.items[0] = replacement.items[0].copyWith(
      fileName: 'episode-05.mkv',
    );
    await tester.pumpWidget(
      IrisApp(
        router: harness.router,
        downloadsRepository: replacement,
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.activeSubscriptions, 1);
    expect(replacement.activeSubscriptions, 1);
    expect(announced, hasLength(3));
    setStatus('3', DownloadStatus.failed);
    await tester.pumpAndSettle();
    expect(announced, hasLength(3));
    replacement.items[0] = replacement.items[0].copyWith(
      status: DownloadStatus.failed,
    );
    replacement.emit();
    await tester.pumpAndSettle();
    expect(announced.last, 'Download failed: Frieren, Episode 05');
    expect(announced, hasLength(4));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(repository.activeSubscriptions, 1);
    expect(replacement.activeSubscriptions, 0);
    replacement.items[1] = replacement.items[1].copyWith(
      status: DownloadStatus.completed,
    );
    replacement.emit();
    await tester.pump();
    expect(announced, hasLength(4));
    await _close(tester, repository, harness);
    expect(repository.activeSubscriptions, 0);
    await replacement.changes.close();
  });

  testWidgets('queue semantics name each release and accessible action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final repository = _Downloads(count: 0);
      repository.items = [
        _item(
          '0',
          DownloadStatus.downloading,
        ).copyWith(fileName: 'episode-01.mkv', sourceTitle: 'Active release'),
        _item(
          '1',
          DownloadStatus.queued,
        ).copyWith(fileName: 'episode-01.mkv', sourceTitle: 'First release'),
        _item(
          '2',
          DownloadStatus.queued,
        ).copyWith(fileName: 'episode-01.mkv', sourceTitle: 'Second release'),
        _item(
          'paused',
          DownloadStatus.paused,
        ).copyWith(fileName: 'episode-01.mkv', sourceTitle: 'Paused release'),
        _item(
          'failed',
          DownloadStatus.failed,
        ).copyWith(fileName: 'episode-01.mkv', sourceTitle: 'Failed release'),
        _item('source', DownloadStatus.paused).copyWith(
          animeId: '',
          animeTitle: '',
          sourceTitle: 'Local release',
          fileName: 'episode-01.mkv',
        ),
        _item('file', DownloadStatus.paused).copyWith(
          animeId: '',
          animeTitle: '',
          sourceTitle: '',
          fileName: 'Local movie.mkv',
        ),
      ];
      final harness = await _mount(
        tester,
        repository,
        size: const Size(1440, 1600),
      );
      await tester.tap(find.byKey(const Key('download_queue_open')));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('1. Frieren, Episode 01, FIRST RELEASE'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('2. Frieren, Episode 01, SECOND RELEASE'),
        findsOneWidget,
      );
      for (final label in [
        'Frieren, Episode 01, FIRST RELEASE, More actions',
        'Frieren, Episode 01, SECOND RELEASE, More actions',
        'Pause: Frieren, Episode 01, ACTIVE RELEASE',
        'Resume: Frieren, Episode 01, PAUSED RELEASE',
        'Try Again: Frieren, Episode 01, FAILED RELEASE',
        'Resume: Local release, Episode 01',
        'Resume: Local movie',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('queue_menu_1')))
            .getSemanticsData()
            .tooltip,
        isEmpty,
      );
      tester.semantics.customAction(
        find.semantics.byLabel('1. Frieren, Episode 01, FIRST RELEASE'),
        const CustomSemanticsAction(label: 'Move down'),
      );
      await tester.pumpAndSettle();
      expect(repository.waiting, ['2', '1']);
      await _close(tester, repository, harness);
    } finally {
      semantics.dispose();
    }
  });

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('$kind reorders both directions and keeps active progress', (
      tester,
    ) async {
      final repository = _Downloads();
      final harness = await _mount(
        tester,
        repository,
        size: kind == PointerDeviceKind.mouse
            ? const Size(1440, 900)
            : const Size(390, 844),
      );
      await tester.tap(find.byKey(const Key('download_queue_open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('queue_handle_0')), findsNothing);
      final active = repository.items.first;
      await _move(tester, '1', '3', down: true, kind: kind);
      expect(repository.waiting, ['2', '3', '1', '4']);
      expect(repository.items.first, same(active));
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repository.waiting, ['1', '2', '3', '4']);
      await _move(tester, '3', '1', down: false, kind: kind);
      expect(repository.waiting, ['3', '1', '2', '4']);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_queue_open')));
      await tester.pumpAndSettle();
      expect(repository.waiting, ['3', '1', '2', '4']);
      await _close(tester, repository, harness);
    });
  }

  testWidgets(
    'menu, restored keyboard focus, pause, resume and failures are visible',
    (tester) async {
      final repository = _Downloads();
      final harness = await _mount(
        tester,
        repository,
        size: const Size(1440, 900),
      );
      await tester.tap(find.byKey(const Key('download_queue_open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('queue_menu_1')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
      expect(repository.waiting, ['2', '1', '3', '4']);
      await tester.tap(find.byKey(const ValueKey('queue_menu_2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('queue_pause_2')));
      await tester.pumpAndSettle();
      expect(repository.waiting, ['1', '3', '4']);
      await tester.ensureVisible(find.byKey(const ValueKey('queue_pause_2')));
      await tester.tap(find.byKey(const ValueKey('queue_pause_2')));
      await tester.pumpAndSettle();
      expect(repository.waiting, ['1', '3', '4', '2']);
      repository.failReorder = true;
      await tester.tap(find.byKey(const ValueKey('queue_menu_3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('queue_next_3')));
      await tester.pumpAndSettle();
      expect(repository.waiting, ['1', '3', '4', '2']);
      expect(
        find.text('Unable to change download order. Try again.'),
        findsOneWidget,
      );
      await _close(tester, repository, harness);
    },
  );

  testWidgets(
    'completion cancels a live drag and never loses a waiting episode',
    (tester) async {
      final repository = _Downloads();
      final harness = await _mount(tester, repository);
      await tester.tap(find.byKey(const Key('download_queue_open')));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('queue_handle_3'))),
      );
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump(const Duration(milliseconds: 100));
      repository.completeCurrent();
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repository.waiting, ['2', '3', '4']);
      expect(
        repository.items
            .singleWhere((item) => item.status == DownloadStatus.downloading)
            .id,
        '1',
      );
      await _close(tester, repository, harness);
    },
  );

  testWidgets(
    'a long queue scrolls by its rows and auto-scrolls a dragged handle',
    (tester) async {
      final repository = _Downloads(count: 18);
      final harness = await _mount(tester, repository);
      await tester.tap(find.byKey(const Key('download_queue_open')));
      await tester.pumpAndSettle();
      final before = repository.waiting;
      await tester.drag(find.byKey(const ValueKey('1')), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(repository.waiting, before);
      final scrollable = find.descendant(
        of: find.byKey(const Key('queue_scroll')),
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      final point = tester.getCenter(
        find.byKey(const ValueKey('queue_handle_1')),
      );
      final gesture = await tester.startGesture(point);
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 20));
      final bounds = tester.getRect(find.byKey(const Key('queue_scroll')));
      await gesture.moveTo(Offset(point.dx, bounds.bottom - 2));
      for (var frame = 0; frame < 90; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        final position = tester.state<ScrollableState>(scrollable).position;
        if (position.pixels >= position.maxScrollExtent - 1) break;
      }
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        greaterThan(500),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(repository.waiting.last, '1');
      await _close(tester, repository, harness);
    },
  );

  testWidgets(
    'files cleanup keeps downloads and file access; a live player blocks it',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final busy in [false, true]) {
          final repository = _Downloads(busy: busy);
          final harness = await _mount(tester, repository);
          await tester.tap(find.byKey(const Key('download_files_open')));
          await tester.pumpAndSettle();
          final button = tester.widget<OutlinedButton>(
            find.byKey(const Key('download_files_clear_temporary')),
          );
          expect(button.onPressed == null, busy);
          expect(
            tester
                .getSemantics(
                  find.byKey(const Key('download_files_clear_temporary')),
                )
                .getSemanticsData()
                .label,
            'Clear temporary files',
          );
          final ids = repository.items.map((item) => item.id).toList();
          if (!busy) {
            await tester.tap(
              find.byKey(const Key('download_files_clear_temporary')),
            );
            await tester.pumpAndSettle();
            expect(repository.cleared, 1);
            expect(find.text('Temporary files deleted'), findsOneWidget);
            expect(repository.items.map((item) => item.id), ids);
            expect(
              find.byKey(const Key('download_files_clear_temporary')),
              findsNothing,
            );
            await tester.tap(find.byTooltip('Close'));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('download_files_open')),
              findsOneWidget,
            );
          }
          await _close(tester, repository, harness);
        }
      } finally {
        semantics.dispose();
      }
    },
  );
}
