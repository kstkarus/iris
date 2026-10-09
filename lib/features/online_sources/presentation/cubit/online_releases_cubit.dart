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

  Future<void> load() async {
    emit(const OnlineReleasesLoading());
    var found = const <OnlineRelease>[];
    try {
      await for (final releases in _search.watchReleases(
        shikimoriId: shikimoriId,
        titles: titles,
      )) {
        if (isClosed) return;
        found = releases;
        emit(OnlineReleasesLoaded(releases, searching: true));
      }
    } on Object {
      if (isClosed) return;
      emit(const OnlineReleasesFailure());
      return;
    }
    if (isClosed) return;
    emit(
      found.isEmpty ? const OnlineReleasesEmpty() : OnlineReleasesLoaded(found),
    );
  }
}
