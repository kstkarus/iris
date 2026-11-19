import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/repositories/online_releases_search.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';

/// The anime's releases on video servers, looked up next to its torrents
/// and shown as each server answers.
class OnlineReleasesCubit extends Cubit<OnlineReleasesState> {
  OnlineReleasesCubit({
    required this.shikimoriId,
    required this.titles,
    required OnlineReleasesSearch search,
  }) : _search = search,
       super(const OnlineReleasesLoading());

  final String shikimoriId;
  final List<String> titles;
  final OnlineReleasesSearch _search;
  StreamIterator<List<OnlineRelease>>? _activeSearch;

  Future<void> load() async {
    if (isClosed) return;
    _activeSearch?.cancel().ignore();
    _activeSearch = null;
    emit(const OnlineReleasesLoading());
    var found = const <OnlineRelease>[];
    StreamIterator<List<OnlineRelease>>? active;
    try {
      final results = StreamIterator(
        _search.watchReleases(shikimoriId: shikimoriId, titles: titles),
      );
      active = _activeSearch = results;
      while (await results.moveNext()) {
        if (!identical(_activeSearch, results)) return;
        found = results.current;
        emit(OnlineReleasesLoaded(found, searching: true));
      }
      if (identical(_activeSearch, results)) {
        emit(
          found.isEmpty
              ? const OnlineReleasesEmpty()
              : OnlineReleasesLoaded(found),
        );
      }
    } on Object {
      if (!isClosed && identical(_activeSearch, active)) {
        emit(const OnlineReleasesFailure());
      }
    } finally {
      if (identical(_activeSearch, active)) _activeSearch = null;
      await active?.cancel();
    }
  }

  @override
  Future<void> close() async {
    final active = _activeSearch;
    _activeSearch = null;
    final closed = super.close();
    await active?.cancel();
    await closed;
  }
}
