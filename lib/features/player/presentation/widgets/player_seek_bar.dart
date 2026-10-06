import 'package:flutter/material.dart';

import 'package:iris/shared/utils/duration_formatter.dart';

/// Times over the video: beside the timeline and above its thumb.
const playerTimeStyle = TextStyle(
  color: Colors.white,
  fontSize: 15,
  fontWeight: FontWeight.w500,
  fontFeatures: [FontFeature.tabularFigures()],
  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
);

/// The immersive player's timeline: played and buffered parts, a thumb,
/// and the time under the pointer while hovering or dragging. Seeks on tap
/// and when a drag ends.
class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
    required this.color,
    this.onActiveChanged,
    super.key,
  });

  static const height = 52.0;

  final Duration position;
  final Duration duration;

  /// How far the stream is buffered, from the start of the file.
  final Duration buffered;
  final ValueChanged<Duration> onSeek;
  final Color color;

  /// Whether the pointer hovers or drags the bar, so the controls around it
  /// stay visible meanwhile.
  final ValueChanged<bool>? onActiveChanged;

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  static const _labelWidth = 80.0;

  /// Visible over a bright frame, still apart from the buffered part.
  static const _unplayedColor = Color(0x52FFFFFF);
  static const _bufferedColor = Color(0x80FFFFFF);

  /// Lines up with the centre of 40 px buttons aligned to the bar's bottom.
  static const _trackTop = 32.0;

  double? _hoverFraction;
  double? _dragFraction;

  bool get _active => _hoverFraction != null || _dragFraction != null;

  double _fractionOf(Duration value) {
    final total = widget.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (value.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration _durationAt(double fraction) {
    return Duration(
      milliseconds: (widget.duration.inMilliseconds * fraction).round(),
    );
  }

  double _fractionAt(double dx, double width) {
    if (width <= 0) return 0;
    return (dx / width).clamp(0.0, 1.0);
  }

  void _update(VoidCallback change) {
    final wasActive = _active;
    setState(change);
    if (wasActive != _active) widget.onActiveChanged?.call(_active);
  }

  void _seekTo(double fraction) {
    if (widget.duration <= Duration.zero) return;
    widget.onSeek(_durationAt(fraction));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final played = _dragFraction ?? _fractionOf(widget.position);
        final buffered = _fractionOf(widget.buffered);
        final hover = _dragFraction == null ? _hoverFraction : null;
        final trackHeight = _active ? 6.0 : 4.0;
        final thumbSize = _active ? 18.0 : 14.0;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (event) => _update(
            () => _hoverFraction = _fractionAt(event.localPosition.dx, width),
          ),
          onExit: (_) => _update(() => _hoverFraction = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) =>
                _seekTo(_fractionAt(details.localPosition.dx, width)),
            onHorizontalDragStart: (details) => _update(
              () =>
                  _dragFraction = _fractionAt(details.localPosition.dx, width),
            ),
            onHorizontalDragUpdate: (details) => _update(
              () =>
                  _dragFraction = _fractionAt(details.localPosition.dx, width),
            ),
            onHorizontalDragEnd: (_) {
              final fraction = _dragFraction;
              _update(() => _dragFraction = null);
              if (fraction != null) _seekTo(fraction);
            },
            onHorizontalDragCancel: () => _update(() => _dragFraction = null),
            child: SizedBox(
              key: const Key('player_seek_bar'),
              height: PlayerSeekBar.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The time shows where a click or the drag would go;
                  // at rest the readout beside the bar has it.
                  if (_active)
                    _timeLabel(
                      width: width,
                      fraction: hover ?? played,
                      text: formatPlaybackPosition(
                        _durationAt(hover ?? played),
                      ),
                      key: const Key('player_seek_bar_time'),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _trackTop - trackHeight / 2,
                    height: trackHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(trackHeight),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const ColoredBox(color: _unplayedColor),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: buffered,
                            child: const ColoredBox(color: _bufferedColor),
                          ),
                          if (hover != null)
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: hover,
                              child: const ColoredBox(color: Colors.white24),
                            ),
                          FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: played,
                            child: ColoredBox(color: widget.color),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: played * width - thumbSize / 2,
                    top: _trackTop - thumbSize / 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: widget.color,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _timeLabel({
    required double width,
    required double fraction,
    required String text,
    Key? key,
  }) {
    final left = (fraction * width - _labelWidth / 2).clamp(
      0.0,
      (width - _labelWidth).clamp(0.0, double.infinity),
    );
    return Positioned(
      left: left,
      top: 0,
      width: _labelWidth,
      child: Text(
        text,
        key: key,
        textAlign: TextAlign.center,
        style: playerTimeStyle,
      ),
    );
  }
}
