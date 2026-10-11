part of '../media_kit_player_viewport_factory.dart';

class _PlayerControlsStatsPanel extends StatelessWidget {
  const _PlayerControlsStatsPanel({
    required this.immersive,
    required this.listenable,
    required this.diagnosticsListenable,
    required this.startupPhaseListenable,
    required this.trackListenable,
    required this.bufferMarginStateListenable,
    required this.isBufferingListenable,
  });

  final ValueListenable<PlayerPlaybackStats?> listenable;
  final ValueListenable<PlayerPlaybackDiagnostics?> diagnosticsListenable;
  final ValueListenable<PlayerEnginePhase> startupPhaseListenable;
  final ValueListenable<Track> trackListenable;
  final ValueListenable<PlayerBufferMarginState> bufferMarginStateListenable;
  final ValueListenable<bool> isBufferingListenable;
  final bool immersive;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        startupPhaseListenable,
        trackListenable,
        bufferMarginStateListenable,
        isBufferingListenable,
        playerDetailedStatsEnabled,
      ]),
      builder: (context, child) {
        if (startupPhaseListenable.value != PlayerEnginePhase.ready) {
          return const SizedBox.shrink();
        }
        // Over a full-bleed video the numbers show up when they explain
        // something: a stall, a thin buffer, or when asked for.
        final detailed = playerDetailedStatsEnabled.value;
        final buffering = isBufferingListenable.value;
        final bufferMargin = bufferMarginStateListenable.value;
        if (immersive &&
            !detailed &&
            !buffering &&
            bufferMargin != PlayerBufferMarginState.insufficient) {
          return const SizedBox.shrink();
        }

        final track = trackListenable.value;
        return PlayerPlaybackStatsListenable(
          listenable: listenable,
          videoCodec: track.video.codec,
          audioCodec: track.audio.codec,
          diagnosticsListenable: diagnosticsListenable,
          bufferMarginState: bufferMargin,
          isBuffering: buffering,
          detailed: detailed,
          immersive: immersive,
        );
      },
    );
  }
}
