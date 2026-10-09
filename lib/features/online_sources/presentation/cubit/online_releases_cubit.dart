import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';

/// The anime's releases on video servers, looked up next to its torrents.
class OnlineReleasesCubit extends Cubit<OnlineReleasesState> {
  OnlineReleasesCubit({
    required this.shikimoriId,
    required this.titles,
    required OnlineSourcesRepository repository,
  }) : _repository = repository,
       super(const OnlineReleasesLoading());

  final String shikimoriId;
  final List<String> titles;
  final OnlineSourcesRepository _repository;

  Future<void> load() async {
    emit(const OnlineReleasesLoading());
    try {
      final releases = await _repository.findReleases(
        shikimoriId: shikimoriId,
        titles: titles,
      );
      if (isClosed) return;
      emit(
        releases.isEmpty
            ? const OnlineReleasesEmpty()
            : OnlineReleasesLoaded(releases),
      );
    } on Object {
      if (isClosed) return;
      emit(const OnlineReleasesFailure());
    }
  }
}
