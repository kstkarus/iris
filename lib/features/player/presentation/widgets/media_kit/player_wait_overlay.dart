part of '../media_kit_player_viewport_factory.dart';

class _BufferingIndicator extends StatelessWidget {
  const _BufferingIndicator({required this.label, this.stats});

  final String label;
  final ValueListenable<PlayerPlaybackStats?>? stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlockRunner(
          color: playerAccentColor(Theme.of(context).colorScheme),
          trackColor: Colors.white24,
        ),
        const SizedBox(height: 12),
        PlayerWaitLabel(
          label: label,
          stats: stats,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}

class _PlayerStartupOverlay extends StatelessWidget {
  const _PlayerStartupOverlay({
    required this.label,
    required this.stats,
    super.key,
  });

  final String label;
  final ValueListenable<PlayerPlaybackStats?> stats;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _BufferingIndicator(label: label, stats: stats),
        ),
      ),
    );
  }
}

/// mpv's buffering once playing; the startup overlay speaks until then.
class _PlayerControlsBufferingOverlay extends StatelessWidget {
  const _PlayerControlsBufferingOverlay({
    required this.engine,
    required this.label,
  });

  final MediaKitPlayerEngine engine;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, child) {
        if (engine.startupState.phase != PlayerEnginePhase.ready ||
            _playerStartupLabel(AppLocalizations.of(context), engine) != null) {
          return const SizedBox.shrink();
        }

        return _BufferingIndicator(label: label);
      },
    );
  }
}
