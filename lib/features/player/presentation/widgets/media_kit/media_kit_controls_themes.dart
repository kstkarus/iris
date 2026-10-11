part of '../media_kit_player_viewport_factory.dart';

/// Video controls flavour and its themes: media_kit's touch controls
/// ([MaterialVideoControls]) on phones and tablets, or none under the
/// immersive player, which draws its own.
sealed class MediaKitVideoControlsThemes {
  const MediaKitVideoControlsThemes();

  List<Widget> get topButtonBar;

  VideoControlsBuilder get controlsBuilder;

  MediaKitControlsDecorator? get decorateControls;

  /// [controlsBuilder] wrapped by [decorateControls].
  VideoControlsBuilder get controls => (state) {
    final controls = controlsBuilder(state);
    return decorateControls?.call(state, controls) ?? controls;
  };
}

final class MediaKitMobileVideoControlsThemes
    extends MediaKitVideoControlsThemes {
  const MediaKitMobileVideoControlsThemes({
    required this.normal,
    required this.fullscreen,
    this.decorateControls,
  });

  final MaterialVideoControlsThemeData normal;
  final MaterialVideoControlsThemeData fullscreen;

  @override
  final MediaKitControlsDecorator? decorateControls;

  @override
  List<Widget> get topButtonBar => normal.topButtonBar;

  @override
  VideoControlsBuilder get controlsBuilder => MaterialVideoControls;
}

/// No media_kit controls: [PlayerImmersiveControls] are drawn over the
/// video instead.
final class MediaKitImmersiveVideoControlsThemes
    extends MediaKitVideoControlsThemes {
  const MediaKitImmersiveVideoControlsThemes({required this.subtitleLift});

  /// Pixels kept clear at the bottom of the Flutter subtitle view.
  final ValueListenable<double> subtitleLift;

  @override
  List<Widget> get topButtonBar => const [];

  /// Draws nothing; only moves the Flutter subtitle view, which belongs to
  /// the [VideoState].
  @override
  VideoControlsBuilder get controlsBuilder =>
      (state) => _SubtitleLift(video: state, lift: subtitleLift);

  @override
  MediaKitControlsDecorator? get decorateControls => null;
}

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
