import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/anime_list/domain/entities/anime_list_query.dart';
import 'package:iris/features/anime_list/domain/repositories/anime_list_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_event.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_state.dart';

class AnimeListBloc extends Bloc<AnimeListEvent, AnimeListState> {
  AnimeListBloc({required AnimeListRepository repository})
    : _repository = repository,
      super(const AnimeListState()) {
    on<AnimeListStarted>(_onStarted);
    on<AnimeListInitialRetryRequested>(_onInitialRetryRequested);
    on<AnimeListNextPageRequested>(_onNextPageRequested);
    on<AnimeListSearchChanged>(_onSearchChanged);
    on<AnimeListSearchCleared>(_onSearchCleared);
    on<AnimeListSortChanged>(_onSortChanged);
    on<AnimeListCriteriaApplied>(_onCriteriaApplied);
    on<AnimeListCriteriaReset>(_onCriteriaReset);
    on<AnimeListPageLoaded>(_onPageLoaded);
    on<AnimeListPageFailed>(_onPageFailed);
  }

  static const pageSize = 12;

  final AnimeListRepository _repository;
  int _requestSessionId = 0;

  /// Whether a list without a search query is fetched; when not, it stays
  /// empty and idle until there is a query.
  @protected
  bool get fetchesWithoutQuery => true;

  void _onStarted(AnimeListStarted event, Emitter<AnimeListState> emit) {
    _restartList(
      emit,
      query: '',
      sort: AnimeListSortOption.popularity,
      filters: const AnimeListFilters(),
    );
  }

  void _onInitialRetryRequested(
    AnimeListInitialRetryRequested event,
    Emitter<AnimeListState> emit,
  ) {
    _restartList(
      emit,
      query: state.query,
      sort: state.sort,
      filters: state.filters,
    );
  }

  void _onNextPageRequested(
    AnimeListNextPageRequested event,
    Emitter<AnimeListState> emit,
  ) {
    if (state.isInitialLoading ||
        state.isLoadingMore ||
        !state.hasLoadedOnce ||
        !state.hasMore) {
      return;
    }

    final sessionId = _requestSessionId;

    emit(
      state.copyWith(isLoadingMore: true, errorType: AnimeListErrorType.none),
    );

    unawaited(
      _fetchPage(
        sessionId: sessionId,
        query: _currentQuery(page: state.page + 1),
        append: true,
      ),
    );
  }

  void _onSearchChanged(
    AnimeListSearchChanged event,
    Emitter<AnimeListState> emit,
  ) {
    final normalizedQuery = event.query.trim();

    if (normalizedQuery == state.query && state.hasLoadedOnce) {
      return;
    }

    _restartList(
      emit,
      query: normalizedQuery,
      sort: state.sort,
      filters: state.filters,
    );
  }

  void _onSearchCleared(
    AnimeListSearchCleared event,
    Emitter<AnimeListState> emit,
  ) {
    if (state.query.isEmpty && state.hasLoadedOnce) {
      return;
    }

    _restartList(emit, query: '', sort: state.sort, filters: state.filters);
  }

  void _onSortChanged(
    AnimeListSortChanged event,
    Emitter<AnimeListState> emit,
  ) {
    if (event.sort == state.sort && state.hasLoadedOnce) {
      return;
    }

    _restartList(
      emit,
      query: state.query,
      sort: event.sort,
      filters: state.filters,
    );
  }

  void _onCriteriaApplied(
    AnimeListCriteriaApplied event,
    Emitter<AnimeListState> emit,
  ) {
    final nextSort = event.sort ?? state.sort;
    final nextFilters = event.filters ?? state.filters;

    if (nextSort == state.sort &&
        nextFilters == state.filters &&
        state.hasLoadedOnce) {
      return;
    }

    _restartList(
      emit,
      query: state.query,
      sort: nextSort,
      filters: nextFilters,
    );
  }

  void _onCriteriaReset(
    AnimeListCriteriaReset event,
    Emitter<AnimeListState> emit,
  ) {
    if (state.sort == AnimeListSortOption.popularity &&
        state.filters == const AnimeListFilters() &&
        state.hasLoadedOnce) {
      return;
    }

    _restartList(
      emit,
      query: state.query,
      sort: AnimeListSortOption.popularity,
      filters: const AnimeListFilters(),
    );
  }

  void _onPageLoaded(AnimeListPageLoaded event, Emitter<AnimeListState> emit) {
    if (event.sessionId != _requestSessionId) {
      return;
    }

    final items = event.append
        ? [...state.items, ...event.result.items]
        : event.result.items;

    emit(
      state.copyWith(
        items: items,
        page: event.result.page,
        query: event.result.query,
        sort: event.query.sort,
        filters: event.query.filters,
        hasMore: event.result.hasMore,
        isInitialLoading: false,
        isLoadingMore: false,
        hasLoadedOnce: true,
        errorType: AnimeListErrorType.none,
      ),
    );
  }

  void _onPageFailed(AnimeListPageFailed event, Emitter<AnimeListState> emit) {
    if (event.sessionId != _requestSessionId) {
      return;
    }

    emit(
      state.copyWith(
        isInitialLoading: false,
        isLoadingMore: false,
        hasLoadedOnce: event.append ? state.hasLoadedOnce : false,
        sort: event.query.sort,
        filters: event.query.filters,
        errorType: event.append
            ? AnimeListErrorType.loadMore
            : AnimeListErrorType.initial,
      ),
    );
  }

  void _restartList(
    Emitter<AnimeListState> emit, {
    required String query,
    required AnimeListSortOption sort,
    required AnimeListFilters filters,
  }) {
    final sessionId = ++_requestSessionId;

    if (query.isEmpty && !fetchesWithoutQuery) {
      emit(AnimeListState(sort: sort, filters: filters, hasMore: false));
      return;
    }

    emit(
      AnimeListState(
        query: query,
        sort: sort,
        filters: filters,
        hasMore: true,
        isInitialLoading: true,
      ),
    );

    unawaited(
      _fetchPage(
        sessionId: sessionId,
        query: AnimeListQuery(
          page: 1,
          limit: pageSize,
          search: query,
          sort: sort,
          filters: filters,
        ),
        append: false,
      ),
    );
  }

  AnimeListQuery _currentQuery({required int page}) {
    return AnimeListQuery(
      page: page,
      limit: pageSize,
      search: state.query,
      sort: state.sort,
      filters: state.filters,
    );
  }

  Future<void> _fetchPage({
    required int sessionId,
    required AnimeListQuery query,
    required bool append,
  }) async {
    try {
      final result = await _repository.fetchAnimePage(query: query);

      add(
        AnimeListPageLoaded(
          sessionId: sessionId,
          result: result,
          query: query,
          append: append,
        ),
      );
    } catch (_) {
      add(
        AnimeListPageFailed(sessionId: sessionId, query: query, append: append),
      );
    }
  }
}
