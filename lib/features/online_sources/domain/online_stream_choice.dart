import 'package:iris/features/online_sources/domain/entities/online_stream.dart';

/// The stream to play, or with [downloadable] to load: the tallest picture
/// at or below [maxQuality] (any, when it is null, "Auto"), or the least
/// tall above it when there is none so low. Loading leaves DASH out and
/// takes an mp4 before HLS of the same height; otherwise the streams' own
/// order, the better player first, settles a tie. Null when no stream fits.
OnlineStream? chooseOnlineStream(
  List<OnlineStream> streams, {
  int? maxQuality,
  bool downloadable = false,
}) {
  final candidates = [
    for (final stream in streams)
      if (!downloadable || stream.format != OnlineStreamFormat.dash) stream,
  ];
  final height = closestQuality(onlineQualities(candidates), maxQuality);
  final matching = [
    for (final stream in candidates)
      if (stream.quality == height) stream,
  ];
  if (matching.isEmpty) return null;
  if (!downloadable) return matching.first;
  return matching.firstWhere(
    (stream) => stream.format == OnlineStreamFormat.mp4,
    orElse: () => matching.first,
  );
}

/// The heights [streams] come in, tallest first; with [downloadable],
/// only those that can be loaded.
List<int> onlineQualities(
  List<OnlineStream> streams, {
  bool downloadable = false,
}) {
  final heights = {
    for (final stream in streams)
      if (!downloadable || stream.format != OnlineStreamFormat.dash)
        stream.quality,
  }.toList()..sort((left, right) => right.compareTo(left));
  return heights;
}

/// Of the [offered] heights (tallest first), the one [wanted] gets: the
/// tallest at or below it, or the least tall above it. The tallest of all
/// for a null [wanted]; null when nothing is offered.
int? closestQuality(List<int> offered, int? wanted) {
  if (offered.isEmpty) return null;
  if (wanted == null) return offered.first;
  for (final height in offered) {
    if (height <= wanted) return height;
  }
  return offered.last;
}
