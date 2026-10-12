import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/domain/player_timeline_parts.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/duration_formatter.dart';
import 'package:iris/shared/utils/equality.dart';

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
///
/// Cut into [parts] when the file's chapters or its opening and ending are
/// known, with the part's name beside the time under the pointer. Cuts that
/// arrive while the bar is up run in from left to right.
class PlayerSeekBar extends StatefulWidget {
  const PlayerSeekBar({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
    required this.color,
    this.parts = const [],
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
  final List<PlayerTimelinePart> parts;

  /// Whether the pointer hovers or drags the bar, so the controls around it
  /// stay visible meanwhile.
  final ValueChanged<bool>? onActiveChanged;

  /// How far a screen reader's increase or decrease moves the position.
  static const _step = Duration(seconds: 10);

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar>
    with SingleTickerProviderStateMixin {
  /// The gap a cut leaves in the track.
  static const _cutWidth = 2.0;

  /// How long one cut takes to open, and how much later the next starts.
  static const _cutOpening = Duration(milliseconds: 240);
  static const _cutStagger = Duration(milliseconds: 50);

  /// Visible over a bright frame, still apart from the buffered part.
  static const _unplayedColor = Color(0x52FFFFFF);
  static const _bufferedColor = Color(0x80FFFFFF);

  /// Lines up with the centre of 40 px buttons aligned to the bar's bottom.
  static const _trackTop = 32.0;

  double? _hoverFraction;
  double? _dragFraction;

  /// Runs the cuts in; at rest at its end, so a bar built with its parts
  /// known shows them at once.
  late final _cuts = AnimationController(vsync: this, value: 1);

  @override
  void didUpdateWidget(PlayerSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final starts = _cutStarts(widget.parts);
    if (sameList(starts, _cutStarts(oldWidget.parts)) || starts.isEmpty) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _cuts.value = 1;
      return;
    }
    _cuts.duration = _cutOpening + _cutStagger * (starts.length - 1);
    _cuts.forward(from: 0);
  }

  @override
  void dispose() {
    _cuts.dispose();
    super.dispose();
  }

  static List<Duration> _cutStarts(List<PlayerTimelinePart> parts) => [
    for (final part in parts.skip(1)) part.start,
  ];

  /// Each cut's position on the bar and how open it is, the leftmost first.
  List<({double fraction, double width})> _cutsNow() {
    final starts = _cutStarts(widget.parts);
    final elapsed = _cuts.value * (_cuts.duration?.inMicroseconds ?? 0);
    return [
      for (final (index, start) in starts.indexed)
        (
          fraction: _fractionOf(start),
          width:
              _cutWidth *
              (_cuts.duration == null
                  ? 1.0
                  : Curves.easeOut.transform(
                      ((elapsed - _cutStagger.inMicroseconds * index) /
                              _cutOpening.inMicroseconds)
                          .clamp(0.0, 1.0),
                    )),
        ),
    ];
  }

  /// The name of the part at [fraction], when it has one.
  String? _partNameAt(double fraction, AppLocalizations l10n) {
    final position = _durationAt(fraction);
    for (final part in widget.parts) {
      final atEnd = part == widget.parts.last && position == part.end;
      if (!part.contains(position) && !atEnd) continue;
      return part.title ??
          switch (part.kind) {
            PlayerSkipKind.opening => l10n.playerPartOpening,
            PlayerSkipKind.ending => l10n.playerPartEnding,
            PlayerSkipKind.recap => l10n.playerPartRecap,
            null => null,
          };
    }
    return null;
  }

  String _pointText(double fraction, AppLocalizations l10n) {
    final time = formatPlaybackPosition(_durationAt(fraction));
    final name = _partNameAt(fraction, l10n);
    return name == null ? time : '$name · $time';
  }

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

  /// The position [delta] away from the current one, kept within the video.
  Duration _positionBy(Duration delta) {
    final target = widget.position + delta;
    if (target < Duration.zero) return Duration.zero;
    if (target > widget.duration) return widget.duration;
    return target;
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
    final l10n = AppLocalizations.of(context);
    final seekable = widget.duration > Duration.zero;
    final partName = _partNameAt(_fractionOf(widget.position), l10n);
    final value = formatPlaybackPosition(widget.position);
    return Semantics(
      slider: true,
      label: l10n.playerSeekBarLabel,
      value: partName == null ? value : '$partName, $value',
      increasedValue: formatPlaybackPosition(_positionBy(PlayerSeekBar._step)),
      decreasedValue: formatPlaybackPosition(_positionBy(-PlayerSeekBar._step)),
      onIncrease: seekable
          ? () => widget.onSeek(_positionBy(PlayerSeekBar._step))
          : null,
      onDecrease: seekable
          ? () => widget.onSeek(_positionBy(-PlayerSeekBar._step))
          : null,
      child: LayoutBuilder(
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
              // Screen readers use the slider above; a tap action here would
              // seek to the middle of the bar.
              excludeFromSemantics: true,
              onTapUp: (details) =>
                  _seekTo(_fractionAt(details.localPosition.dx, width)),
              onHorizontalDragStart: (details) => _update(
                () => _dragFraction = _fractionAt(
                  details.localPosition.dx,
                  width,
                ),
              ),
              onHorizontalDragUpdate: (details) => _update(
                () => _dragFraction = _fractionAt(
                  details.localPosition.dx,
                  width,
                ),
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
                        text: _pointText(hover ?? played, l10n),
                        key: const Key('player_seek_bar_time'),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _trackTop - trackHeight / 2,
                      height: trackHeight,
                      child: ClipPath(
                        key: const Key('player_seek_bar_track'),
                        clipBehavior: Clip.antiAlias,
                        clipper: SeekBarCuts(
                          cuts: _cutsNow(),
                          cutsAt: _cutsNow,
                          reclip: _cuts,
                        ),
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
      ),
    );
  }

  Widget _timeLabel({
    required double width,
    required double fraction,
    required String text,
    Key? key,
  }) {
    // Measured in the style it is drawn in: the theme brings the font.
    final style = DefaultTextStyle.of(context).style.merge(playerTimeStyle);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final labelWidth = math.min(painter.width + 2, width);
    painter.dispose();
    final left = (fraction * width - labelWidth / 2).clamp(
      0.0,
      (width - labelWidth).clamp(0.0, double.infinity),
    );
    return Positioned(
      left: left,
      top: 0,
      width: labelWidth,
      // A pointer preview; the slider's value is where playback is.
      child: ExcludeSemantics(
        child: Text(
          text,
          key: key,
          textAlign: TextAlign.center,
          style: playerTimeStyle,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }
}

/// The track with a gap at each cut, where the video shows through.
class SeekBarCuts extends CustomClipper<Path> {
  SeekBarCuts({required this.cuts, required this.cutsAt, super.reclip});

  /// Where each cut is, as a share of the track, and how wide it is open.
  final List<({double fraction, double width})> cuts;

  /// The cuts as they are now, read again while they run in.
  final List<({double fraction, double width})> Function() cutsAt;

  @override
  Path getClip(Size size) {
    final path = Path();
    var left = 0.0;
    for (final cut in cutsAt()) {
      final x = cut.fraction * size.width;
      final gapLeft = (x - cut.width / 2).clamp(0.0, size.width);
      if (gapLeft > left) {
        path.addRect(Rect.fromLTRB(left, 0, gapLeft, size.height));
      }
      left = math.max(left, (x + cut.width / 2).clamp(0.0, size.width));
    }
    if (left < size.width) {
      path.addRect(Rect.fromLTRB(left, 0, size.width, size.height));
    }
    return path;
  }

  @override
  bool shouldReclip(SeekBarCuts oldClipper) =>
      !_sameCuts(oldClipper.cuts, cuts);

  static bool _sameCuts(
    List<({double fraction, double width})> a,
    List<({double fraction, double width})> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
