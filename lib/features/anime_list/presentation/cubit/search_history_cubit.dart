import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/anime_list/domain/repositories/search_history_repository.dart';
import 'package:iris/shared/utils/serial_queue.dart';

class SearchHistoryCubit extends Cubit<List<String>> {
  SearchHistoryCubit({required SearchHistoryRepository repository})
    : _repository = repository,
      super(
        List.unmodifiable(
          repository.read().where((q) => q.trim().isNotEmpty).take(10),
        ),
      );

  final SearchHistoryRepository _repository;
  final _writes = SerialQueue();

  void record(String query) {
    query = query.trim();
    if (query.isEmpty) return;
    _save(
      [
        query,
        ...state.where((old) => old.toLowerCase() != query.toLowerCase()),
      ].take(10).toList(),
    );
  }

  void remove(String query) =>
      _save(state.where((old) => old != query).toList());
  void clear() => _save(const []);

  void _save(List<String> queries) {
    emit(List.unmodifiable(queries));
    unawaited(
      _writes.run(() async {
        try {
          await _repository.save(queries);
        } on Object catch (error, stackTrace) {
          developer.log(
            'Unable to save recent searches.',
            name: 'iris.search',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }),
    );
  }
}
