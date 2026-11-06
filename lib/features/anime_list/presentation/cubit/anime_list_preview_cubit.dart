import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';

typedef AnimeListPreview = ({bool loading, int? count, bool hasMore});

/// Shikimori has no total: one page gives an exact count or a lower bound.
class AnimeListPreviewCubit extends Cubit<AnimeListPreview> {
  AnimeListPreviewCubit({required AnimeListRepository repository})
    : _repository = repository,
      super((loading: false, count: null, hasMore: false));

  // shortcut: count one page until Shikimori exposes a total.
  static const limit = 50;
  final AnimeListRepository _repository;
  Timer? _debounce;
  int _request = 0;

  void update(AnimeListQuery query) {
    _debounce?.cancel();
    final request = ++_request;
    emit((loading: true, count: null, hasMore: false));
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final result = await _repository.fetchAnimePage(query: query);
        if (isClosed || request != _request) return;
        emit((
          loading: false,
          count: result.items.length,
          hasMore: result.hasMore,
        ));
      } on Exception {
        if (!isClosed && request == _request) {
          emit((loading: false, count: null, hasMore: false));
        }
      }
    });
  }

  void cancel() {
    _debounce?.cancel();
    _request++;
  }

  @override
  Future<void> close() {
    cancel();
    return super.close();
  }
}
