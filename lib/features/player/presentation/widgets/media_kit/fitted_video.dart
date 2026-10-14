part of '../media_kit_player_viewport_factory.dart';

/// The whole video in its box ([BoxFit.contain]), or zoomed until it fills
/// the box ([BoxFit.cover]), cropping what falls outside; the change moves
/// in a quarter of a second, at once when the system asks for less motion.
class _FittedVideo extends StatelessWidget {
  const _FittedVideo({
    required this.fit,
    required this.videoSize,
    required this.child,
  });

  static const zoomDuration = Duration(milliseconds: 250);

  final BoxFit fit;

  /// Null until the video has one: there is nothing to fill with yet.
  final Size? videoSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final zoom = fit == BoxFit.cover
            ? _fillZoom(constraints.biggest, videoSize)
            : 1.0;
        return ClipRect(
          child: TweenAnimationBuilder<double>(
            key: const Key('player_video_zoom'),
            tween: Tween(end: zoom),
            duration: motionDuration(context, zoomDuration),
            curve: Curves.easeInOutCubic,
            builder: (context, zoom, child) =>
                Transform.scale(scale: zoom, child: child),
            child: child,
          ),
        );
      },
    );
  }
}

/// How much a [video] fitted whole into [box] grows to fill it.
double _fillZoom(Size box, Size? video) {
  if (video == null || box.isEmpty || video.isEmpty) return 1;
  final boxShape = box.width / box.height;
  final videoShape = video.width / video.height;
  return videoShape > boxShape ? videoShape / boxShape : boxShape / videoShape;
}
