import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';

/// The file of [files] to continue with: the last one watched, or the one
/// after it when that was finished; null when there is none.
({PlayerVideoFile file, bool isNext})? continueTarget(
  List<PlayerVideoFile> files,
  Map<int, WatchProgress> progressByFile,
) {
  WatchProgress? latest;
  for (final progress in progressByFile.values) {
    if (latest == null || progress.updatedAt.isAfter(latest.updatedAt)) {
      latest = progress;
    }
  }
  if (latest == null) return null;
  final position = files.indexWhere((file) => file.index == latest!.fileIndex);
  if (position < 0) return null;
  if (!latest.isFinished) return (file: files[position], isNext: false);
  if (position + 1 >= files.length) return null;
  return (file: files[position + 1], isNext: true);
}
