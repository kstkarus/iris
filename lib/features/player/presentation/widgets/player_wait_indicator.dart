import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';

export 'package:iris/shared/widgets/block_runner.dart';

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
        DitherSwitcher(
          key: const Key('player_startup_label'),
          duration: const Duration(milliseconds: 300),
          child: Text(
            widget.label,
            key: ValueKey(widget.label),
            style: widget.style?.copyWith(fontFamily: DetailLayout.sansFont),
          ),
        ),
        if (_showStats && stats != null)
          ValueListenableBuilder<PlayerPlaybackStats?>(
            valueListenable: stats,
            builder: (context, value, _) {
              final line = _statsLine(AppLocalizations.of(context), value);
              if (line == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: PixelSeparatedText(
                  line,
                  key: const Key('player_wait_stats'),
                  style: DetailLayout.monoTelemetryStyle(
                    widget.style?.copyWith(
                      color: widget.style?.color?.withValues(alpha: 0.7),
                      fontSize: (widget.style?.fontSize ?? 14) * 0.85,
                    ),
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
