import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class PlayerPlaybackStatsListenable extends StatelessWidget {
  const PlayerPlaybackStatsListenable({
    required this.listenable,
    this.videoCodec,
    this.audioCodec,
    this.isBuffering = false,
    super.key,
  });

  final ValueListenable<PlayerPlaybackStats?> listenable;
  final String? videoCodec;
  final String? audioCodec;
  final bool isBuffering;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayerPlaybackStats?>(
      valueListenable: listenable,
      builder: (context, stats, child) {
        if (stats == null) {
          return const SizedBox.shrink();
        }
        return PlayerPlaybackStatsIndicator(
          stats: stats,
          videoCodec: videoCodec,
          audioCodec: audioCodec,
          isBuffering: isBuffering,
        );
      },
    );
  }
}

class PlayerPlaybackStatsIndicator extends StatelessWidget {
  const PlayerPlaybackStatsIndicator({
    required this.stats,
    this.videoCodec,
    this.audioCodec,
    this.isBuffering = false,
    super.key,
  });

  final PlayerPlaybackStats stats;
  final String? videoCodec;
  final String? audioCodec;
  final bool isBuffering;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ) ??
        const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        );

    final metrics = _buildMetrics(l10n);
    if (metrics.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final visibleMetrics = _selectVisibleMetrics(
                metrics: metrics,
                constraints: constraints,
                textStyle: textStyle,
              );
              final maxChipWidth = _resolveMaxChipWidth(constraints.maxWidth);

              return Wrap(
                spacing: _chipSpacing,
                runSpacing: _chipRunSpacing,
                children: [
                  for (final metric in visibleMetrics)
                    _MetricChip(
                      metric: metric,
                      textStyle: textStyle,
                      maxWidth: maxChipWidth,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_PlayerOverlayMetricItem> _buildMetrics(AppLocalizations l10n) {
    // TODO(kstk): Add a user-facing setting to choose which overlay metrics
    // should stay visible in the player.
    final items = <_PlayerOverlayMetricItem>[
      _PlayerOverlayMetricItem(
        value: _formatTransferRate(stats.downloadRateBytesPerSecond),
        icon: Icons.download_rounded,
        priority: 0,
        tooltip: l10n.playerRuntimeStatsSpeed(
          _formatTransferRate(stats.downloadRateBytesPerSecond),
        ),
      ),
      _PlayerOverlayMetricItem(
        value: stats.activePeers.toString(),
        icon: Icons.hub_outlined,
        priority: 1,
        tooltip: l10n.playerRuntimeStatsPeers(stats.activePeers.toString()),
      ),
    ];

    final shortVideoCodec = _shortCodec(videoCodec);
    if (shortVideoCodec != null) {
      items.add(
        _PlayerOverlayMetricItem(
          value: shortVideoCodec,
          icon: Icons.movie_outlined,
          priority: 2,
          tooltip: l10n.playerRuntimeStatsVideoCodec(shortVideoCodec),
        ),
      );
    }

    final shortAudioCodec = _shortCodec(audioCodec);
    if (shortAudioCodec != null) {
      items.add(
        _PlayerOverlayMetricItem(
          value: shortAudioCodec,
          icon: Icons.audiotrack_rounded,
          priority: 3,
          tooltip: l10n.playerRuntimeStatsAudioCodec(shortAudioCodec),
        ),
      );
    }

    final memory = stats.appMemoryBytes;
    if (memory != null) {
      final formattedMemory = _formatMemory(memory);
      items.add(
        _PlayerOverlayMetricItem(
          value: formattedMemory,
          icon: Icons.memory_rounded,
          priority: 4,
          tooltip: l10n.playerRuntimeStatsMemory(formattedMemory),
        ),
      );
    }

    if (isBuffering) {
      items.add(
        _PlayerOverlayMetricItem(
          value: l10n.playerBuffering,
          icon: Icons.hourglass_top_rounded,
          priority: 5,
          tooltip: l10n.playerBuffering,
        ),
      );
    }

    items.sort((left, right) => left.priority.compareTo(right.priority));
    return items;
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.metric,
    required this.textStyle,
    required this.maxWidth,
  });

  final _PlayerOverlayMetricItem metric;
  final TextStyle textStyle;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final chip = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(31),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(metric.icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  metric.value,
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (metric.tooltip == null) {
      return chip;
    }

    return Tooltip(message: metric.tooltip!, child: chip);
  }
}

class _PlayerOverlayMetricItem {
  const _PlayerOverlayMetricItem({
    required this.value,
    required this.icon,
    required this.priority,
    this.tooltip,
  });

  final String value;
  final IconData icon;
  final int priority;
  final String? tooltip;
}

List<_PlayerOverlayMetricItem> _selectVisibleMetrics({
  required List<_PlayerOverlayMetricItem> metrics,
  required BoxConstraints constraints,
  required TextStyle textStyle,
}) {
  final maxWidth = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
      ? constraints.maxWidth
      : 280.0;
  if (maxWidth <= 0) {
    return metrics;
  }

  final maxChipWidth = _resolveMaxChipWidth(maxWidth);
  final visible = <_PlayerOverlayMetricItem>[];
  var rowWidth = 0.0;
  var rowCount = 1;

  for (final metric in metrics) {
    final chipWidth = _measureChipWidth(
      metric: metric,
      textStyle: textStyle,
      maxChipWidth: maxChipWidth,
    );
    final projectedWidth = rowWidth == 0
        ? chipWidth
        : rowWidth + _chipSpacing + chipWidth;

    if (projectedWidth <= maxWidth) {
      visible.add(metric);
      rowWidth = projectedWidth;
      continue;
    }

    if (rowCount >= 2) {
      continue;
    }

    visible.add(metric);
    rowCount++;
    rowWidth = chipWidth;
  }

  return visible;
}

double _measureChipWidth({
  required _PlayerOverlayMetricItem metric,
  required TextStyle textStyle,
  required double maxChipWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: metric.value, style: textStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: maxChipWidth);

  final measuredWidth =
      painter.width + _chipHorizontalPadding + _chipIconWidth + _chipIconGap;
  return measuredWidth.clamp(_chipMinimumWidth, maxChipWidth);
}

double _resolveMaxChipWidth(double maxWidth) {
  final target = maxWidth * 0.58;
  return math.max(_chipMinimumWidth, math.min(target, _chipMaximumWidth));
}

String _formatTransferRate(int bytesPerSecond) {
  return '${_formatBytes(bytesPerSecond)}/s';
}

String _formatMemory(int bytes) {
  return _formatBytes(bytes);
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final fractionDigits = unitIndex <= 1 || value >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}

String? _shortCodec(String? codec) {
  if (codec == null) {
    return null;
  }

  final trimmed = codec.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final normalized = trimmed.toLowerCase();
  if (normalized.contains('av1') || normalized.contains('av01')) {
    return 'AV1';
  }
  if (normalized.contains('hevc') ||
      normalized.contains('h265') ||
      normalized.contains('h.265') ||
      normalized.contains('x265')) {
    return 'HEVC';
  }
  if (normalized.contains('avc') ||
      normalized.contains('h264') ||
      normalized.contains('h.264') ||
      normalized.contains('x264')) {
    return 'H.264';
  }
  if (normalized.contains('opus')) {
    return 'Opus';
  }
  if (normalized.contains('flac')) {
    return 'FLAC';
  }
  if (normalized.contains('eac3')) {
    return 'E-AC-3';
  }
  if (normalized.contains('ac3')) {
    return 'AC3';
  }
  if (normalized.contains('aac')) {
    return 'AAC';
  }
  if (normalized.contains('dts')) {
    return 'DTS';
  }

  return trimmed;
}

const _chipSpacing = 6.0;
const _chipRunSpacing = 6.0;
const _chipHorizontalPadding = 14.0;
const _chipIconWidth = 12.0;
const _chipIconGap = 4.0;
const _chipMinimumWidth = 58.0;
const _chipMaximumWidth = 132.0;
