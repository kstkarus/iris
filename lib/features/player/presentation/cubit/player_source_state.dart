import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/player_continue_target.dart';
import 'package:iris/shared/utils/equality.dart';

sealed class PlayerSourceState {
  const PlayerSourceState();
}

final class PlayerSourceInitial extends PlayerSourceState {
  const PlayerSourceInitial();

  @override
  bool operator ==(Object other) => other is PlayerSourceInitial;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class PlayerSourceLoading extends PlayerSourceState {
  const PlayerSourceLoading();

  @override
  bool operator ==(Object other) => other is PlayerSourceLoading;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class PlayerSourceReady extends PlayerSourceState {
  const PlayerSourceReady(
    this.files, {
    this.downloadSource,
    this.localSessionId,
    this.downloads,
    this.quality,
    this.selecting = false,
    this.selected = const {},
    this.addingBatch = false,
    this.enqueueFailed = false,
  });

  final List<PlayerVideoFile> files;
  final PreparedDownloadSource? downloadSource;
  final String? localSessionId;
  final Map<int, DownloadItem>? downloads;
  final int? quality;
  final bool selecting;
  final Set<int> selected;
  final bool addingBatch;
  final bool enqueueFailed;

  DownloadItem? downloadFor(int index) => downloads?[index];

  bool canDownload(int index) =>
      downloadSource != null && downloads != null && downloadFor(index) == null;

  bool get hasNewDownloads => files.any((file) => canDownload(file.index));

  ({Set<int> next, Set<int> unwatched, Set<int> all}) downloadPresets(
    Map<int, WatchProgress> progressByFile,
    Set<int> listed,
  ) {
    final target = continueTarget(files, progressByFile, listed: listed);
    final start = target == null ? 0 : files.indexOf(target.file);
    final next = <int>{};
    final unwatched = <int>{};
    final all = <int>{};
    for (final (position, file) in files.indexed) {
      final index = file.index;
      if (!canDownload(index)) continue;
      all.add(index);
      if (progressByFile[index]?.isFinished ?? listed.contains(index)) {
        continue;
      }
      unwatched.add(index);
      if (position >= start && next.length < 5) next.add(index);
    }
    return (next: next, unwatched: unwatched, all: all);
  }

  PlayerSourceReady copyWith({
    Map<int, DownloadItem>? downloads,
    int? Function()? quality,
    bool? selecting,
    Set<int>? selected,
    bool? addingBatch,
    bool? enqueueFailed,
  }) {
    return PlayerSourceReady(
      files,
      downloadSource: downloadSource,
      localSessionId: localSessionId,
      downloads: downloads ?? this.downloads,
      quality: quality == null ? this.quality : quality(),
      selecting: selecting ?? this.selecting,
      selected: selected ?? this.selected,
      addingBatch: addingBatch ?? this.addingBatch,
      enqueueFailed: enqueueFailed ?? this.enqueueFailed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerSourceReady &&
      sameList(other.files, files) &&
      other.downloadSource == downloadSource &&
      other.localSessionId == localSessionId &&
      (identical(other.downloads, downloads) ||
          (other.downloads != null &&
              downloads != null &&
              sameMap(other.downloads!, downloads!))) &&
      other.quality == quality &&
      other.selecting == selecting &&
      sameSet(other.selected, selected) &&
      other.addingBatch == addingBatch &&
      other.enqueueFailed == enqueueFailed;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(files),
    downloadSource,
    localSessionId,
    downloads == null ? null : Object.hashAllUnordered(downloads!.values),
    quality,
    selecting,
    Object.hashAllUnordered(selected),
    addingBatch,
    enqueueFailed,
  );
}

enum PlayerSourceFailureType { unsupportedSource, unableToPrepare }

final class PlayerSourceFailure extends PlayerSourceState {
  const PlayerSourceFailure(this.type);

  final PlayerSourceFailureType type;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerSourceFailure && other.type == type;
  }

  @override
  int get hashCode => type.hashCode;
}
