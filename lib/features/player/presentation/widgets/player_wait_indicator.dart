import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/presentation/widgets/player_playback_stats_indicator.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

/// The player's wait: one block runs around a 3×3 square. Square like the
/// play button whose place it takes, and a loop rather than a row of
/// segments, so it never reads as a level or a share loaded.
class BlockRunner extends StatefulWidget {
  const BlockRunner({
    required this.color,
    required this.trackColor,
    this.cell = 12,
    this.gap = 3,
    super.key,
  });

  final Color color;
  final Color trackColor;
  final double cell;
  final double gap;

  /// One step per block, in the noise's 10 fps.
  static const step = Duration(milliseconds: 100);

  @override
  State<BlockRunner> createState() => _BlockRunnerState();
}

class _BlockRunnerState extends State<BlockRunner>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: BlockRunner.step * _ring.length,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.cell * 3 + widget.gap * 2;
    return CustomPaint(
      size: Size.square(side),
      painter: _RunnerPainter(
        progress: _controller,
        color: widget.color,
        trackColor: widget.trackColor,
        cell: widget.cell,
        gap: widget.gap,
      ),
    );
  }
}

/// The square's outer cells, clockwise from the top left.
const _ring = [(0, 0), (1, 0), (2, 0), (2, 1), (2, 2), (1, 2), (0, 2), (0, 1)];

class _RunnerPainter extends CustomPainter {
  _RunnerPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.cell,
    required this.gap,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;
  final Color trackColor;
  final double cell;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final head = (progress.value * _ring.length).floor() % _ring.length;
    final paint = Paint();
    for (var index = 0; index < _ring.length; index++) {
      final behind = (head - index) % _ring.length;
      paint.color = switch (behind) {
        0 => color,
        // A one-block trail gives the loop its direction.
        1 => color.withValues(alpha: color.a * 0.45),
        _ => trackColor,
      };
      final (column, row) = _ring[index];
      canvas.drawRect(
        Rect.fromLTWH(column * (cell + gap), row * (cell + gap), cell, cell),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RunnerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.cell != cell ||
      oldDelegate.gap != gap;
}

/// What the wait is, and after a few seconds of it, whether anything is
/// arriving: download speed and peers.
class PlayerWaitLabel extends StatefulWidget {
  const PlayerWaitLabel({
    required this.label,
    required this.style,
    this.stats,
    super.key,
  });

  final String label;
  final TextStyle? style;

  /// The torrent's numbers; null where they would not explain the wait.
  final ValueListenable<PlayerPlaybackStats?>? stats;

  /// Short waits stay quiet; numbers matter once the wait feels long.
  static const statsDelay = Duration(seconds: 5);

  @override
  State<PlayerWaitLabel> createState() => _PlayerWaitLabelState();
}

class _PlayerWaitLabelState extends State<PlayerWaitLabel> {
  Timer? _statsTimer;
  bool _showStats = false;

  @override
  void initState() {
    super.initState();
    _statsTimer = Timer(PlayerWaitLabel.statsDelay, () {
      if (mounted) setState(() => _showStats = true);
    });
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          key: const Key('player_startup_label'),
          style: widget.style,
        ),
        if (_showStats && stats != null)
          ValueListenableBuilder<PlayerPlaybackStats?>(
            valueListenable: stats,
            builder: (context, value, _) {
              final line = _statsLine(AppLocalizations.of(context), value);
              if (line == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  line,
                  key: const Key('player_wait_stats'),
                  style: widget.style?.copyWith(
                    color: widget.style?.color?.withValues(alpha: 0.7),
                    fontSize: (widget.style?.fontSize ?? 14) * 0.85,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// "2.4 MB/s · 12 peers". A torrent that moves nothing says it has no peers
/// yet, which is why it waits; a local file reports zeros too and says
/// nothing.
String? _statsLine(AppLocalizations l10n, PlayerPlaybackStats? stats) {
  if (stats == null) return null;
  final rate = stats.downloadRateBytesPerSecond;
  final peers = stats.activePeers;
  if (rate <= 0 && peers <= 0) {
    return stats.isTorrent ? l10n.playerWaitNoPeers : null;
  }
  return [
    formatTransferRate(l10n, rate),
    l10n.playerWaitPeers(peers),
  ].join(' · ');
}
