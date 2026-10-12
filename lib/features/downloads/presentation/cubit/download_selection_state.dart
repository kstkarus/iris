import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';

sealed class DownloadSelectionState {
  const DownloadSelectionState();
}

class DownloadSelectionInitial extends DownloadSelectionState {
  const DownloadSelectionInitial();
}

class DownloadSelectionLoading extends DownloadSelectionState {
  const DownloadSelectionLoading();
}

class DownloadSelectionReady extends DownloadSelectionState {
  const DownloadSelectionReady(this.source, {this.quality});

  final PreparedDownloadSource source;

  /// The height an online episode is loaded in at most, one of the
  /// source's qualities; null for the best, and for a torrent.
  final int? quality;
}

class DownloadSelectionEnqueuing extends DownloadSelectionState {
  const DownloadSelectionEnqueuing({
    required this.source,
    required this.file,
    this.quality,
  });

  final PreparedDownloadSource source;
  final DownloadableFile file;
  final int? quality;
}

class DownloadSelectionQueued extends DownloadSelectionState {
  const DownloadSelectionQueued(this.item);

  final DownloadItem item;
}

enum DownloadSelectionFailureType {
  unableToPrepare,
  unsupported,
  unableToQueue,
}

class DownloadSelectionFailure extends DownloadSelectionState {
  const DownloadSelectionFailure(this.type);

  final DownloadSelectionFailureType type;
}
