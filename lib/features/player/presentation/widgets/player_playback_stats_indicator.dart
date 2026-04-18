import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class PlayerPlaybackStatsIndicator extends StatelessWidget {
  const PlayerPlaybackStatsIndicator({required this.stats, super.key});

  final PlayerPlaybackStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final memory = stats.appMemoryBytes;

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.playerRuntimeStatsSpeed(
                  _formatTransferRate(stats.downloadRateBytesPerSecond),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              if (memory != null)
                Text(
                  l10n.playerRuntimeStatsMemory(_formatMemory(memory)),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
