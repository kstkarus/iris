import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/presentation/widgets/player_buffer_health_tracker.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class PlayerPlaybackStatsListenable extends StatelessWidget {
  const PlayerPlaybackStatsListenable({
    required this.listenable,
    this.videoCodec,
    this.audioCodec,
    this.diagnostics,
    this.diagnosticsListenable,
    this.isBuffering = false,
    this.bufferMarginState,
    this.detailed = true,
    this.immersive = false,
    super.key,
  });

  final ValueListenable<PlayerPlaybackStats?> listenable;
  final bool detailed;

  /// Drawn like the immersive player's other controls over the video.
  final bool immersive;
  final String? videoCodec;
  final String? audioCodec;
  final PlayerPlaybackDiagnostics? diagnostics;
  final ValueListenable<PlayerPlaybackDiagnostics?>? diagnosticsListenable;
  final bool isBuffering;
  final PlayerBufferMarginState? bufferMarginState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: diagnosticsListenable == null
          ? listenable
          : Listenable.merge([listenable, diagnosticsListenable!]),
      builder: (context, child) {
        final stats = listenable.value;
        if (stats == null) {
          return const SizedBox.shrink();
        }
        return PlayerPlaybackStatsIndicator(
          stats: stats,
          videoCodec: videoCodec,
          audioCodec: audioCodec,
          diagnostics: diagnosticsListenable?.value ?? diagnostics,
          isBuffering: isBuffering,
          bufferMarginState: bufferMarginState,
          detailed: detailed,
          immersive: immersive,
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
    this.diagnostics,
    this.isBuffering = false,
    this.bufferMarginState,
    this.detailed = true,
    this.immersive = false,
    super.key,
  });

  /// Metrics shown when technical details are off: what a viewer needs to
  /// understand stalls (speed, buffer, buffering).
  static const _essentialPriorities = {0, 2, 9};

  final PlayerPlaybackStats stats;
  final String? videoCodec;
  final String? audioCodec;
  final PlayerPlaybackDiagnostics? diagnostics;
  final bool isBuffering;
  final PlayerBufferMarginState? bufferMarginState;

  /// Also show peers, decoder, output, codecs and memory.
  final bool detailed;

  /// One dark glass readout like the immersive player's buttons, with the
  /// buffer state in its icon's colour, instead of coloured chips.
  final bool immersive;

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

    final metrics = _buildMetrics(l10n)
        .where(
          (metric) =>
              detailed || _essentialPriorities.contains(metric.priority),
        )
        .toList();
    if (metrics.isEmpty) {
      return const SizedBox.shrink();
    }
    if (immersive) return _ImmersiveReadout(metrics: metrics);

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
        value: _formatTransferRate(l10n, stats.downloadRateBytesPerSecond),
        icon: Icons.download_rounded,
        priority: 0,
        tooltip: l10n.playerRuntimeStatsSpeed(
          _formatTransferRate(l10n, stats.downloadRateBytesPerSecond),
        ),
      ),
      _PlayerOverlayMetricItem(
        value: stats.activePeers.toString(),
        icon: Icons.hub_outlined,
        priority: 1,
        tooltip: l10n.playerRuntimeStatsPeers(stats.activePeers.toString()),
      ),
    ];

    final bufferedWindowProgress = _resolveBufferedWindowProgress(stats);
    final bufferSufficient =
        (bufferMarginState ?? resolvePlayerBufferMargin(stats)) ==
        PlayerBufferMarginState.sufficient;
    if (bufferedWindowProgress > 0) {
      items.add(
        _PlayerOverlayMetricItem(
          value: _formatBufferedWindowProgress(bufferedWindowProgress),
          icon: Icons.timelapse_rounded,
          priority: 2,
          backgroundColor: bufferSufficient
              ? const Color(0x4032D583)
              : const Color(0x40F59E0B),
          accentColor: bufferSufficient
              ? const Color(0xFF32D583)
              : const Color(0xFFF59E0B),
        ),
      );
    }

    final hwdec = _nonBlank(diagnostics?.hwdecCurrent);
    if (hwdec != null) {
      items.add(
        _PlayerOverlayMetricItem(
          value: hwdec,
          icon: Icons.memory_rounded,
          priority: 3,
          tooltip: 'hwdec $hwdec',
        ),
      );
    }

    final currentVo = _nonBlank(diagnostics?.currentVo);
    if (currentVo != null) {
      items.add(
        _PlayerOverlayMetricItem(
          value: currentVo,
          icon: Icons.output_rounded,
          priority: 4,
          tooltip: 'vo $currentVo',
        ),
      );
    }

    final videoDecoder = _nonBlank(diagnostics?.videoDecoder);
    if (videoDecoder != null) {
      items.add(
        _PlayerOverlayMetricItem(
          value: videoDecoder,
          icon: Icons.developer_board_rounded,
          priority: 5,
          tooltip: _decoderTooltip(diagnostics),
        ),
      );
    }

    final shortVideoCodec = _shortCodec(diagnostics?.videoCodec ?? videoCodec);
    if (shortVideoCodec != null) {
      items.add(
        _PlayerOverlayMetricItem(
          value: shortVideoCodec,
          icon: Icons.movie_outlined,
          priority: 6,
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
          priority: 7,
          tooltip: l10n.playerRuntimeStatsAudioCodec(shortAudioCodec),
        ),
      );
    }

    final memory = stats.appMemoryBytes;
    if (memory != null) {
      final formattedMemory = _formatMemory(l10n, memory);
      items.add(
        _PlayerOverlayMetricItem(
          value: formattedMemory,
          icon: Icons.memory_rounded,
          priority: 8,
          tooltip: l10n.playerRuntimeStatsMemory(formattedMemory),
        ),
      );
    }

    if (isBuffering) {
      items.add(
        _PlayerOverlayMetricItem(
          value: l10n.playerBuffering,
          icon: Icons.hourglass_top_rounded,
          priority: 9,
          tooltip: l10n.playerBuffering,
        ),
      );
    }

    items.sort((left, right) => left.priority.compareTo(right.priority));
    return items;
  }
}

class PlayerPlaybackDiagnostics {
  const PlayerPlaybackDiagnostics({
    this.hwdecCurrent,
    this.currentVo,
    this.videoCodec,
    this.videoDecoder,
    this.videoDecoderDescription,
  });

  final String? hwdecCurrent;
  final String? currentVo;
  final String? videoCodec;
  final String? videoDecoder;
  final String? videoDecoderDescription;

  bool get isEmpty =>
      _nonBlank(hwdecCurrent) == null &&
      _nonBlank(currentVo) == null &&
      _nonBlank(videoCodec) == null &&
      _nonBlank(videoDecoder) == null &&
      _nonBlank(videoDecoderDescription) == null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerPlaybackDiagnostics &&
        other.hwdecCurrent == hwdecCurrent &&
        other.currentVo == currentVo &&
        other.videoCodec == videoCodec &&
        other.videoDecoder == videoDecoder &&
        other.videoDecoderDescription == videoDecoderDescription;
  }

  @override
  int get hashCode => Object.hash(
    hwdecCurrent,
    currentVo,
    videoCodec,
    videoDecoder,
    videoDecoderDescription,
  );
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
          color: metric.backgroundColor ?? Colors.white.withAlpha(31),
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
    this.backgroundColor,
    this.accentColor,
  });

  final String value;
  final IconData icon;
  final int priority;
  final String? tooltip;
  final Color? backgroundColor;

  /// The icon's colour in the immersive readout, for states.
  final Color? accentColor;
}

/// Metrics as a quiet caption over the video: no box, so it reads as
/// information next to the buttons rather than as one more button.
class _ImmersiveReadout extends StatelessWidget {
  const _ImmersiveReadout({required this.metrics});

  static const _maxValueWidth = 160.0;
  static const _shadows = [Shadow(color: Colors.black87, blurRadius: 6)];

  final List<_PlayerOverlayMetricItem> metrics;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Colors.white70,
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: _shadows,
    );
    return IgnorePointer(
      child: Padding(
        key: const Key('player_stats_readout'),
        // Centres the first line on the 48 px back button beside it.
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Wrap(
          spacing: 20,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final metric in metrics)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    metric.icon,
                    size: 16,
                    color: metric.accentColor ?? Colors.white54,
                    shadows: _shadows,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxValueWidth),
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
          ],
        ),
      ),
    );
  }
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

String _formatTransferRate(AppLocalizations l10n, int bytesPerSecond) {
  return l10n.playerRate(_formatBytes(l10n, bytesPerSecond));
}

String _formatMemory(AppLocalizations l10n, int bytes) {
  return _formatBytes(l10n, bytes);
}

double _resolveBufferedWindowProgress(PlayerPlaybackStats stats) {
  if (stats.readaheadWindow <= 0 || stats.bufferPieces <= 0) {
    return 0;
  }

  return (stats.bufferPieces / stats.readaheadWindow).clamp(0.0, 1.0);
}

String _formatBufferedWindowProgress(double progress) {
  return '${(progress * 100).round()}%';
}

String _formatBytes(AppLocalizations l10n, int bytes) {
  final units = [
    l10n.byteUnitB,
    l10n.byteUnitKB,
    l10n.byteUnitMB,
    l10n.byteUnitGB,
  ];
  var value = bytes.toDouble();
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final fractionDigits = unitIndex <= 1 || value >= 10 ? 0 : 1;
  final number = NumberFormat.decimalPatternDigits(
    locale: l10n.localeName,
    decimalDigits: fractionDigits,
  ).format(value);
  return '$number ${units[unitIndex]}';
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

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String? _decoderTooltip(PlayerPlaybackDiagnostics? diagnostics) {
  if (diagnostics == null) {
    return null;
  }

  final description = _nonBlank(diagnostics.videoDecoderDescription);
  final decoder = _nonBlank(diagnostics.videoDecoder);
  if (description == null) {
    return decoder == null ? null : 'decoder $decoder';
  }
  if (decoder == null) {
    return description;
  }
  return '$decoder: $description';
}

const _chipSpacing = 6.0;
const _chipRunSpacing = 6.0;
const _chipHorizontalPadding = 14.0;
const _chipIconWidth = 12.0;
const _chipIconGap = 4.0;
const _chipMinimumWidth = 58.0;
const _chipMaximumWidth = 132.0;
