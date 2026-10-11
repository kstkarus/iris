part of '../media_kit_player_viewport_factory.dart';

/// media_kit's controls slot under [PlayerImmersiveControls], which draw
/// the real controls over the video: it shows nothing and only keeps the
/// Flutter subtitle view (no libass) above [lift] pixels of controls.
VideoControlsBuilder _subtitleLiftControls(ValueListenable<double> lift) =>
    (state) => _SubtitleLift(video: state, lift: lift);

/// Keeps the Flutter subtitle view above [lift] pixels of controls.
class _SubtitleLift extends StatefulWidget {
  const _SubtitleLift({required this.video, required this.lift});

  final VideoState video;
  final ValueListenable<double> lift;

  @override
  State<_SubtitleLift> createState() => _SubtitleLiftState();
}

class _SubtitleLiftState extends State<_SubtitleLift> {
  @override
  void initState() {
    super.initState();
    widget.lift.addListener(_apply);
    // The subtitle view mounts in the same frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
  }

  @override
  void didUpdateWidget(covariant _SubtitleLift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lift != widget.lift) {
      oldWidget.lift.removeListener(_apply);
      widget.lift.addListener(_apply);
    }
  }

  @override
  void dispose() {
    widget.lift.removeListener(_apply);
    super.dispose();
  }

  void _apply() {
    if (!mounted || !widget.video.mounted) return;
    final base = widget.video.widget.subtitleViewConfiguration.padding;
    widget.video.setSubtitleViewPadding(
      base.copyWith(bottom: base.bottom + widget.lift.value),
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
