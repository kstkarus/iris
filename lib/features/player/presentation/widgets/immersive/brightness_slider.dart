part of '../player_immersive_controls.dart';

/// The screen's brightness by touch: a square-cut vertical track under a
/// sun, centred in the room between the top and bottom controls and
/// short of filling it.
/// Dragging or tapping along it sets the brightness; [onActive] tells while
/// a finger drags, so the controls stay meanwhile.
class _BrightnessSlider extends StatefulWidget {
  const _BrightnessSlider({required this.control, required this.onActive});

  /// The target's width; the glyph and track are centred in it.
  static const width = 48.0;

  /// How far the glyph sits inside the target, so it lines up with the
  /// titles below.
  static const glyphInset = 15.0;

  /// The bar's glyph size by touch.
  static const _glyphSize = 18.0;
  static const _gap = 12.0;
  static const _maxTrack = 104.0;
  static const _minTrack = 48.0;
  static const _step = 0.1;

  final ScreenBrightnessControl control;
  final ValueChanged<bool> onActive;

  @override
  State<_BrightnessSlider> createState() => _BrightnessSliderState();
}

class _BrightnessSliderState extends State<_BrightnessSlider> {
  double? _value;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    if (_dragging) widget.onActive(false);
    super.dispose();
  }

  Future<void> _load() async {
    final value = await widget.control.current();
    if (mounted && _value == null) setState(() => _value = value);
  }

  void _set(double value) {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped == _value) return;
    setState(() => _value = clamped);
    unawaited(widget.control.set(clamped));
  }

  void _setAt(Offset local, double trackHeight) =>
      _set(1 - local.dy / trackHeight);

  void _setDragging(bool dragging) {
    if (dragging == _dragging) return;
    _dragging = dragging;
    widget.onActive(dragging);
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    if (value == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final track = math.min(
          _BrightnessSlider._maxTrack,
          constraints.maxHeight -
              _BrightnessSlider._glyphSize -
              _BrightnessSlider._gap,
        );
        // Too little room beside the titles: better none than a stub.
        if (track < _BrightnessSlider._minTrack) return const SizedBox.shrink();
        const step = _BrightnessSlider._step;
        return Center(
          child: Semantics(
            slider: true,
            label: l10n.playerBrightness,
            value: '${(value * 100).round()}%',
            increasedValue:
                '${((value + step).clamp(0.0, 1.0) * 100).round()}%',
            decreasedValue:
                '${((value - step).clamp(0.0, 1.0) * 100).round()}%',
            onIncrease: () => _set(value + step),
            onDecrease: () => _set(value - step),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _ShadowedGlyph(
                  glyph: PixelIcon(
                    PixelGlyph.brightness,
                    size: _BrightnessSlider._glyphSize,
                    color: Colors.white,
                    fineGrain: true,
                  ),
                ),
                const SizedBox(height: _BrightnessSlider._gap),
                GestureDetector(
                  key: const Key('player_brightness_slider'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _setAt(details.localPosition, track),
                  onVerticalDragStart: (details) {
                    _setDragging(true);
                    _setAt(details.localPosition, track);
                  },
                  onVerticalDragUpdate: (details) =>
                      _setAt(details.localPosition, track),
                  onVerticalDragEnd: (_) => _setDragging(false),
                  onVerticalDragCancel: () => _setDragging(false),
                  child: SizedBox(
                    width: _BrightnessSlider.width,
                    height: track,
                    child: CustomPaint(painter: _BrightnessTrackPainter(value)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A thin track, lit from the bottom up to [value], with a square thumb.
class _BrightnessTrackPainter extends CustomPainter {
  const _BrightnessTrackPainter(this.value);

  static const _trackWidth = 4.0;
  static const _thumb = 14.0;

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.width / 2;
    final track = Rect.fromLTWH(
      centre - _trackWidth / 2,
      0,
      _trackWidth,
      size.height,
    );
    canvas.drawRect(track, Paint()..color = Colors.white30);
    final level = size.height * (1 - value);
    canvas.drawRect(
      Rect.fromLTRB(track.left, level, track.right, track.bottom),
      Paint()..color = Colors.white,
    );
    final thumbTop = (level - _thumb / 2).clamp(0.0, size.height - _thumb);
    canvas.drawRect(
      Rect.fromLTWH(centre - _thumb / 2, thumbTop, _thumb, _thumb),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_BrightnessTrackPainter old) => old.value != value;
}
