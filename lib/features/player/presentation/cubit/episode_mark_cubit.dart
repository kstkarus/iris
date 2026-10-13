import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/mark_episode_watched.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';

sealed class EpisodeMarkState {
  const EpisodeMarkState();
}

/// Nothing to say.
final class EpisodeMarkIdle extends EpisodeMarkState {
  const EpisodeMarkIdle();
}

/// The episode's number is a guess from the file name: asks first.
final class EpisodeMarkOffered extends EpisodeMarkState {
  const EpisodeMarkOffered(this.episode);

  final int episode;
}

final class EpisodeMarkSaving extends EpisodeMarkState {
  const EpisodeMarkSaving();
}

/// Marked; [mark] is what undo puts back. [undoFailed]: an undo was
/// refused, so the mark stands and undo can be tried again.
final class EpisodeMarkDone extends EpisodeMarkState {
  const EpisodeMarkDone(this.episode, this.mark, {this.undoFailed = false});

  final int episode;
  final EpisodeMarked mark;
  final bool undoFailed;
}

final class EpisodeMarkFailed extends EpisodeMarkState {
  const EpisodeMarkFailed(this.episode);

  final int episode;
}

/// Counts the episode just watched in the user's Shikimori list.
///
/// An online release numbers its episodes, so it is marked at once (with
/// undo); a torrent's number is read from the file name, so it is offered
/// first. Without an account, an anime or a whole episode number nothing
/// happens.
class EpisodeMarkCubit extends Cubit<EpisodeMarkState> {
  EpisodeMarkCubit({
    required MarkEpisodeWatched markEpisode,
    required String? userId,
  }) : _markEpisode = markEpisode,
       _userId = userId,
       super(const EpisodeMarkIdle());

  final MarkEpisodeWatched _markEpisode;
  final String? _userId;
  String _animeId = '';

  /// Playback reached the ending of [source]'s current file.
  void watched(AnimePlayerSource source) {
    final episode = source.episodeNumber;
    if (_userId == null || source.animeId.isEmpty || episode == null) return;
    _animeId = source.animeId;
    final given = source.files.any(
      (file) => file.index == source.fileIndex && file.episodeNumber != null,
    );
    if (given) {
      _mark(episode);
    } else {
      emit(EpisodeMarkOffered(episode));
    }
  }

  /// Takes the offer, or tries a failed mark again.
  void confirm() {
    switch (state) {
      case EpisodeMarkOffered(:final episode) ||
          EpisodeMarkFailed(:final episode):
        _mark(episode);
      default:
    }
  }

  Future<void> undo() async {
    final userId = _userId;
    final current = state;
    if (userId == null || current is! EpisodeMarkDone) return;
    emit(const EpisodeMarkIdle());
    try {
      await _markEpisode.undo(
        userId: userId,
        animeId: _animeId,
        mark: current.mark,
      );
    } on Object {
      if (!isClosed) {
        emit(EpisodeMarkDone(current.episode, current.mark, undoFailed: true));
      }
    }
  }

  /// The notice timed out or was put away.
  void dismiss() {
    if (state is! EpisodeMarkSaving) emit(const EpisodeMarkIdle());
  }

  Future<void> _mark(int episode) async {
    final userId = _userId;
    if (userId == null) return;
    emit(const EpisodeMarkSaving());
    try {
      final result = await _markEpisode(
        userId: userId,
        animeId: _animeId,
        episode: episode,
      );
      if (isClosed) return;
      emit(switch (result) {
        // The list already counts it: nothing to say.
        EpisodeAlreadyMarked() => const EpisodeMarkIdle(),
        final EpisodeMarked mark => EpisodeMarkDone(episode, mark),
      });
    } on Object {
      if (!isClosed) emit(EpisodeMarkFailed(episode));
    }
  }
}
