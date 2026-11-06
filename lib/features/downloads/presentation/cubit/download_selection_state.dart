import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/shared/utils/equality.dart';

sealed class DownloadSelectionState {
  const DownloadSelectionState();
}

class DownloadSelectionInitial extends DownloadSelectionState {
  const DownloadSelectionInitial();
}

class DownloadSelectionLoading extends DownloadSelectionState {
  const DownloadSelectionLoading();
}

/// The source's files to choose from, each with what became of it.
class DownloadSelectionReady extends DownloadSelectionState {
  const DownloadSelectionReady(
    this.source, {
    this.quality,
    this.downloads = const {},
    this.adding = const {},
    this.notAdded = const {},
    this.addingBatch = false,
    this.selecting = false,
    this.selected = const {},
  });

  final PreparedDownloadSource source;

  /// The height an online episode is loaded in at most, one of the
  /// source's qualities; null for the best, and for a torrent.
  final int? quality;

  /// The source's files already among the downloads, by file index.
  final Map<int, DownloadItem> downloads;

  /// Files being added to the queue just now, by index.
  final Set<int> adding;

  /// Files the queue did not take, by index, until they are tried again.
  final Set<int> notAdded;
  final bool addingBatch;
  final bool selecting;
  final Set<int> selected;

  bool get canStartSelection =>
      !selecting &&
      !addingBatch &&
      adding.isEmpty &&
      source.files.any((file) => canSelect(file.index));

  bool canSelect(int index) =>
      !adding.contains(index) &&
      switch (downloads[index]?.status) {
        null || DownloadStatus.paused || DownloadStatus.failed => true,
        _ => false,
      };

  DownloadSelectionReady copyWith({
    int? Function()? quality,
    Map<int, DownloadItem>? downloads,
    Set<int>? adding,
    Set<int>? notAdded,
    bool? addingBatch,
    bool? selecting,
    Set<int>? selected,
  }) {
    return DownloadSelectionReady(
      source,
      quality: quality == null ? this.quality : quality(),
      downloads: downloads ?? this.downloads,
      adding: adding ?? this.adding,
      notAdded: notAdded ?? this.notAdded,
      addingBatch: addingBatch ?? this.addingBatch,
      selecting: selecting ?? this.selecting,
      selected: selected ?? this.selected,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DownloadSelectionReady &&
      identical(other.source, source) &&
      other.quality == quality &&
      other.addingBatch == addingBatch &&
      other.selecting == selecting &&
      sameSet(other.selected, selected) &&
      sameMap(other.downloads, downloads) &&
      sameSet(other.adding, adding) &&
      sameSet(other.notAdded, notAdded);

  @override
  int get hashCode => Object.hash(
    source,
    quality,
    addingBatch,
    selecting,
    Object.hashAllUnordered(selected),
    Object.hashAllUnordered(downloads.values),
    Object.hashAllUnordered(adding),
    Object.hashAllUnordered(notAdded),
  );
}

enum DownloadSelectionFailureType { unableToPrepare, unsupported }

class DownloadSelectionFailure extends DownloadSelectionState {
  const DownloadSelectionFailure(this.type);

  final DownloadSelectionFailureType type;
}
