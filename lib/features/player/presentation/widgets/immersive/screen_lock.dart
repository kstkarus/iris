part of '../player_immersive_controls.dart';

/// The screen lock by touch: nothing over the video takes a touch while it
/// is on, so a hand holding the phone cannot pause or seek; a tap shows the
/// way out for a few seconds.
enum _ScreenLock {
  unlocked,
  locked,

  /// Still locked, with the unlock plate showing.
  revealed;

  static const plateShownFor = Duration(seconds: 3);
}

/// Over the whole locked player: takes every touch, and shows the unlock
/// plate while [revealed].
class _LockLayer extends StatelessWidget {
  const _LockLayer({
    required this.revealed,
    required this.onReveal,
    required this.onUnlock,
  });

  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.playerScreenLocked,
      child: GestureDetector(
        key: const Key('player_lock_layer'),
        behavior: HitTestBehavior.opaque,
        onTap: onReveal,
        child: revealed
            ? Center(
                child: OutlinedButton(
                  key: const Key('player_unlock_button'),
                  onPressed: onUnlock,
                  style: _overVideoButtonStyle(Theme.of(context)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PixelIcon(PixelGlyph.lockOpen, size: 21),
                      const SizedBox(width: 10),
                      Text(l10n.playerUnlockScreen),
                    ],
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}
