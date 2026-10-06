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
  const DownloadSelectionReady(this.source);

  final PreparedDownloadSource source;
}

class DownloadSelectionEnqueuing extends DownloadSelectionState {
  const DownloadSelectionEnqueuing({required this.source, required this.file});

  final PreparedDownloadSource source;
  final DownloadableFile file;
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
