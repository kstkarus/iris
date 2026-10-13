import 'package:media_kit/media_kit.dart';

/// Completes once the player has a video size: at once when [state]
/// already has one, or with the [widths] event that brings it.
///
/// `Player.open` clears the size and mpv sets it again when the new file's
/// video output is up, so this marks a file's first frame. The video
/// controller's own first-frame signal fires only once in its life.
Future<void> playerVideoSized({
  required PlayerState Function() state,
  required Stream<int?> widths,
}) async {
  bool sized() => (state().width ?? 0) > 0 && (state().height ?? 0) > 0;
  if (sized()) return;
  await widths.firstWhere((_) => sized());
}
