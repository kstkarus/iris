import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';

/// The file of [files] to continue with; null when there is none.
///
/// A file stopped partway here is gone on with. Otherwise it is the file
/// after the furthest one finished here or counted in the user's list
/// ([listed], by index), so an episode watched on another device moves it
/// on; when the list has every file but this device does not, this
/// device's place is kept, as that is a rewatch.
({PlayerVideoFile file, bool isNext})? continueTarget(
  List<PlayerVideoFile> files,
  Map<int, WatchProgress> progressByFile, {
  Set<int> listed = const {},
}) {
  WatchProgress? latest;
  for (final progress in progressByFile.values) {
    if (latest == null || progress.updatedAt.isAfter(latest.updatedAt)) {
      latest = progress;
    }
  }
  final latestPosition = latest == null
      ? -1
      : files.indexWhere((file) => file.index == latest!.fileIndex);
  if (latest != null && latestPosition >= 0 && !latest.isFinished) {
    return (file: files[latestPosition], isNext: false);
  }

  final local = latestPosition >= 0 ? latestPosition + 1 : null;
  var furthestListed = -1;
  for (final (position, file) in files.indexed) {
    if (listed.contains(file.index)) furthestListed = position;
  }
  final fromList = furthestListed >= 0 ? furthestListed + 1 : null;

  for (final next in [
    if (fromList != null && (local == null || fromList > local)) fromList,
    ?local,
  ]) {
    if (next < files.length) return (file: files[next], isNext: true);
  }
  return null;
}
