import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/anime_list/domain/entities/anime_list_page_result.dart';
import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/cubit/anime_list_preview_cubit.dart';

void main() {
  const first = AnimeListQuery(page: 1, limit: 50);
  const next = AnimeListQuery(page: 1, limit: 50, search: 'test');

  test('debounces edits, ignores stale counts and cancels a closed sheet', () {
    fakeAsync((async) {
      final repository = _Repository();
      final cubit = AnimeListPreviewCubit(repository: repository);
      cubit.update(first);
      async.elapse(const Duration(milliseconds: 350));
      cubit.update(next);
      repository.requests[0].complete(_page(hasMore: true));
      async.flushMicrotasks();
      expect(cubit.state.count, isNull);
      expect(cubit.state.loading, isTrue);
      async.elapse(const Duration(milliseconds: 350));
      repository.requests[1].complete(_page());
      async.flushMicrotasks();
      expect(cubit.state, (loading: false, count: 0, hasMore: false));
      cubit.update(first);
      async.elapse(const Duration(milliseconds: 100));
      cubit.update(next);
      async.elapse(const Duration(milliseconds: 350));
      expect(repository.queries.length, 3);
      expect(repository.queries.last, next);
      cubit.cancel();
      repository.requests.last.complete(_page(hasMore: true));
      async.flushMicrotasks();
      expect(cubit.state.count, isNull);
      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  test('a failed preview falls back to an uncounted apply action', () {
    fakeAsync((async) {
      final repository = _Repository();
      final cubit = AnimeListPreviewCubit(repository: repository);
      cubit.update(first);
      async.elapse(const Duration(milliseconds: 350));
      repository.requests.single.completeError(Exception('offline'));
      async.flushMicrotasks();
      expect(cubit.state, (loading: false, count: null, hasMore: false));
      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });
}

AnimeListPageResult _page({bool hasMore = false}) =>
    AnimeListPageResult(items: const [], page: 1, hasMore: hasMore, query: '');

class _Repository implements AnimeListRepository {
  final queries = <AnimeListQuery>[];
  final requests = <Completer<AnimeListPageResult>>[];

  @override
  Future<AnimeListPageResult> fetchAnimePage({required AnimeListQuery query}) {
    queries.add(query);
    final result = Completer<AnimeListPageResult>();
    requests.add(result);
    return result.future;
  }
}
