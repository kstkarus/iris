import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/mark_episode_watched.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';

sealed class EpisodeMarkState {
  const EpisodeMarkState();
}

final class EpisodeMarkIdle extends EpisodeMarkState {
  const EpisodeMarkIdle();
}

final class EpisodeMarkOffered extends EpisodeMarkState {
  const EpisodeMarkOffered(this.episode);
  final int episode;
}

enum EpisodeMarkAction { mark, undo, restore }

final class EpisodeMarkSaving extends EpisodeMarkState {
  const EpisodeMarkSaving(this.episode, this.action);
  final int episode;
  final EpisodeMarkAction action;
}

final class EpisodeMarkDone extends EpisodeMarkState {
  const EpisodeMarkDone(this.episode, this.mark);
  final int episode;
  final EpisodeMarked mark;
}

final class EpisodeMarkUndone extends EpisodeMarkState {
  const EpisodeMarkUndone(this.episode, this.mark);
  final int episode;
  final EpisodeMarked mark;
}

/// The episode was already counted, but there is no snapshot to undo.
final class EpisodeMarkRecorded extends EpisodeMarkState {
  const EpisodeMarkRecorded(this.episode);
  final int episode;
}

final class EpisodeMarkFailed extends EpisodeMarkState {
  const EpisodeMarkFailed(this.episode, this.action, {this.mark});
  final int episode;
  final EpisodeMarkAction action;
  final EpisodeMarked? mark;
}

/// Saved on this device, but not confirmed by Shikimori yet.
final class EpisodeMarkQueued extends EpisodeMarkState {
  const EpisodeMarkQueued(this.episode, {this.failed = false});
  final int episode;
  final bool failed;
}

/// The list changed elsewhere; undo must not overwrite that change.
final class EpisodeMarkConflict extends EpisodeMarkState {
  const EpisodeMarkConflict(this.episode);
  final int episode;
}

class _MarkItem {
  _MarkItem(this.animeId, this.episode, this.state);
  final String animeId;
  final int episode;
  EpisodeMarkState state;
  EpisodeMarkUpdate? lastUpdate;
  bool keepResult = false;
}

/// Counts watched episodes and retains unresolved notices across file changes.
class EpisodeMarkCubit extends Cubit<EpisodeMarkState> {
  EpisodeMarkCubit({
    required EpisodeMarker markEpisode,
    required String? userId,
    required int Function() sessionGeneration,
    String animeId = '',
  }) : _markEpisode = markEpisode,
       _animeId = animeId,
       _userId = userId,
       _readSessionGeneration = sessionGeneration,
       _accountGeneration = sessionGeneration(),
       super(const EpisodeMarkIdle()) {
    final sync = markEpisode;
    if (sync is EpisodeMarkSync) {
      _updates = (sync as EpisodeMarkSync).markUpdates.listen(_onUpdate);
    }
    _loadPending();
  }

  final EpisodeMarker _markEpisode;
  final String _animeId;
  final int Function() _readSessionGeneration;
  final _items = <_MarkItem>[];
  final _revision = ValueNotifier<int>(0);
  StreamSubscription<EpisodeMarkUpdate>? _updates;
  _MarkItem? _shown;
  String? _userId;
  int _session = 0;
  int _accountGeneration;

  ValueListenable<int> get revisions => _revision;
  List<_MarkItem> get _available => _items
      .where(
        (item) =>
            (item == _shown && item.state is! EpisodeMarkIdle) ||
            _attention(item.state) ||
            _busy(item.state) ||
            item.keepResult,
      )
      .toList();
  int get pendingCount => _available.length;
  int get pendingIndex => _shown == null ? -1 : _available.indexOf(_shown!);

  void showNextPending() {
    final available = _available;
    if (available.length < 2) return;
    final index = _shown == null ? -1 : available.indexOf(_shown!);
    _shown = available[(index + 1) % available.length];
    emit(_shown!.state);
    _revision.value++;
  }

  void accountChanged(String? userId) {
    final generation = _readSessionGeneration();
    if (userId == _userId && generation == _accountGeneration) return;
    _userId = userId;
    _accountGeneration = generation;
    _session++;
    _items.clear();
    _shown = null;
    if (!isClosed) {
      _loadPending();
      emit(_shown?.state ?? const EpisodeMarkIdle());
      _revision.value++;
    }
  }

  void _loadPending() {
    final userId = _userId;
    final sync = _markEpisode;
    if (userId == null ||
        _animeId.isEmpty ||
        sync is! EpisodeMarkSync ||
        !_isCurrent(_session, userId)) {
      return;
    }
    for (final entry in (sync as EpisodeMarkSync).pendingMarks(
      userId: userId,
      animeId: _animeId,
    )) {
      _items.add(
        _MarkItem(
          entry.animeId,
          entry.episode,
          EpisodeMarkQueued(entry.episode, failed: entry.blocked),
        ),
      );
    }
    _shown = _nextItem();
    if (_shown != null) emit(_shown!.state);
  }

  void watched(AnimePlayerSource source) {
    final userId = _userId;
    final episode = source.episodeNumber;
    if (userId == null ||
        !_isCurrent(_session, userId) ||
        source.animeId.isEmpty ||
        episode == null) {
      return;
    }
    if (_items.any(
      (item) =>
          item.animeId == source.animeId &&
          item.episode == episode &&
          (_attention(item.state) || _busy(item.state)),
    )) {
      return;
    }
    final given = source.files.any(
      (file) => file.index == source.fileIndex && file.episodeNumber != null,
    );
    final item = _MarkItem(
      source.animeId,
      episode,
      given
          ? EpisodeMarkSaving(episode, EpisodeMarkAction.mark)
          : EpisodeMarkOffered(episode),
    );
    _items.add(item);
    _revision.value++;
    if (_shown == null ||
        (!_attention(_shown!.state) && !_busy(_shown!.state))) {
      _shown = item;
      emit(item.state);
    }
    if (given) unawaited(_mark(item, EpisodeMarkAction.mark));
  }

  void confirm() {
    final item = _shown;
    if (item == null) return;
    switch (item.state) {
      case EpisodeMarkOffered():
        item.keepResult = true;
        unawaited(_mark(item, EpisodeMarkAction.mark));
      case EpisodeMarkFailed(:final action)
          when action != EpisodeMarkAction.undo:
        item.keepResult = true;
        unawaited(_mark(item, action));
      case EpisodeMarkQueued():
        item.keepResult = true;
        unawaited(_mark(item, EpisodeMarkAction.mark, retry: true));
      case EpisodeMarkUndone():
        unawaited(_mark(item, EpisodeMarkAction.restore));
      default:
    }
  }

  Future<void> undo() async {
    final item = _shown;
    final userId = _userId;
    final session = _session;
    if (item == null || userId == null || !_isCurrent(session, userId)) return;
    final mark = switch (item.state) {
      EpisodeMarkDone(:final mark) => mark,
      EpisodeMarkFailed(action: EpisodeMarkAction.undo, :final mark) => mark,
      _ => null,
    };
    if (mark == null) return;
    item.keepResult = true;
    _set(item, EpisodeMarkSaving(item.episode, EpisodeMarkAction.undo));
    try {
      final undone = await _markEpisode.undo(
        userId: userId,
        animeId: item.animeId,
        mark: mark,
        isCurrent: () => _isCurrent(session, userId),
      );
      if (!_isCurrent(session, userId)) return;
      _set(
        item,
        undone
            ? EpisodeMarkUndone(item.episode, mark)
            : EpisodeMarkConflict(item.episode),
      );
    } on Object {
      if (_isCurrent(session, userId)) {
        _set(
          item,
          EpisodeMarkFailed(item.episode, EpisodeMarkAction.undo, mark: mark),
        );
      }
    }
  }

  void dismiss() {
    final item = _shown;
    if (item == null || _busy(item.state) || item.state is EpisodeMarkQueued) {
      return;
    }
    _items.remove(item);
    _shown = _nextItem();
    emit(_shown?.state ?? const EpisodeMarkIdle());
    _revision.value++;
  }

  Future<void> _mark(
    _MarkItem item,
    EpisodeMarkAction action, {
    bool retry = false,
  }) async {
    final userId = _userId;
    final session = _session;
    if (userId == null || !_isCurrent(session, userId)) return;
    final previous = item.state;
    item.lastUpdate = null;
    _set(item, EpisodeMarkSaving(item.episode, action));
    try {
      final marker = _markEpisode;
      final result = retry && marker is EpisodeMarkSync
          ? await (marker as EpisodeMarkSync).retryMark(
              userId: userId,
              animeId: item.animeId,
              episode: item.episode,
              isCurrent: () => _isCurrent(session, userId),
            )
          : await marker(
              userId: userId,
              animeId: item.animeId,
              episode: item.episode,
              isCurrent: () => _isCurrent(session, userId),
            );
      if (!_isCurrent(session, userId)) return;
      final update = item.lastUpdate;
      _applyResult(
        item,
        (retry || result is EpisodeMarkDeferred) &&
                update != null &&
                update.result is! EpisodeMarkDeferred
            ? update.result
            : result,
        initial: action == EpisodeMarkAction.mark && !retry,
      );
    } on Object {
      if (_isCurrent(session, userId)) {
        if (previous is EpisodeMarkQueued) {
          _set(item, EpisodeMarkQueued(item.episode, failed: true));
          return;
        }
        final mark = switch (previous) {
          EpisodeMarkUndone(:final mark) => mark,
          EpisodeMarkFailed(:final mark) => mark,
          _ => null,
        };
        _set(item, EpisodeMarkFailed(item.episode, action, mark: mark));
      }
    }
  }

  void _onUpdate(EpisodeMarkUpdate update) {
    final userId = _userId;
    if (userId == null ||
        update.userId != userId ||
        update.generation != _accountGeneration ||
        !_isCurrent(_session, userId)) {
      return;
    }
    for (final item in _items.toList()) {
      if (item.animeId != update.animeId || item.episode != update.episode) {
        continue;
      }
      item.lastUpdate = update;
      if (item.state is EpisodeMarkQueued) _applyResult(item, update.result);
    }
  }

  void _applyResult(
    _MarkItem item,
    EpisodeMarkResult result, {
    bool initial = false,
  }) {
    final failed =
        item.lastUpdate?.failed == true || item.lastUpdate?.blocked == true;
    if (result is EpisodeMarkDeferred &&
        item.state is EpisodeMarkQueued &&
        (item.state as EpisodeMarkQueued).failed == failed) {
      return;
    }
    final next = switch (result) {
      EpisodeMarked() => EpisodeMarkDone(item.episode, result),
      EpisodeAlreadyMarked() =>
        initial ? const EpisodeMarkIdle() : EpisodeMarkRecorded(item.episode),
      EpisodeMarkObsolete() => EpisodeMarkConflict(item.episode),
      EpisodeMarkDeferred() => EpisodeMarkQueued(item.episode, failed: failed),
    };
    _set(item, next);
  }

  bool _attention(EpisodeMarkState state) =>
      state is EpisodeMarkOffered ||
      state is EpisodeMarkFailed ||
      state is EpisodeMarkQueued ||
      state is EpisodeMarkConflict;
  bool _busy(EpisodeMarkState state) => state is EpisodeMarkSaving;

  _MarkItem? _nextItem() {
    for (final item in _items) {
      if (_attention(item.state)) return item;
    }
    for (final item in _items) {
      if (_busy(item.state)) return item;
    }
    for (final item in _items) {
      if (item.keepResult) return item;
    }
    return null;
  }

  void _set(_MarkItem item, EpisodeMarkState next) {
    if (!_items.contains(item)) return;
    if (next is EpisodeMarkDone &&
        (_shown != item ||
            _items.any(
              (candidate) =>
                  candidate != item &&
                  (_attention(candidate.state) || _busy(candidate.state)),
            ))) {
      item.keepResult = true;
    }
    item.state = next;
    if (next is EpisodeMarkIdle) {
      _items.remove(item);
      if (_shown == item) _shown = _nextItem();
    } else if (_shown == item && !_attention(next) && !_busy(next)) {
      final other = _items.where((candidate) => candidate != item).toList();
      final urgent = other.where((candidate) => _attention(candidate.state));
      final busy = other.where((candidate) => _busy(candidate.state));
      if (urgent.isNotEmpty) {
        _shown = urgent.first;
      } else if (busy.isNotEmpty) {
        _shown = busy.first;
      }
    } else if (_shown != item &&
        _attention(next) &&
        (_shown == null ||
            (!_attention(_shown!.state) && !_busy(_shown!.state)))) {
      _shown = item;
    }
    _items.removeWhere(
      (candidate) =>
          candidate != _shown &&
          !_attention(candidate.state) &&
          !_busy(candidate.state) &&
          !candidate.keepResult,
    );
    if (_shown == item || _shown?.state != state) {
      emit(_shown?.state ?? const EpisodeMarkIdle());
    }
    _revision.value++;
  }

  bool _isCurrent(int session, String userId) =>
      !isClosed &&
      session == _session &&
      userId == _userId &&
      _accountGeneration == _readSessionGeneration();

  @override
  Future<void> close() async {
    await _updates?.cancel();
    _revision.dispose();
    return super.close();
  }
}
