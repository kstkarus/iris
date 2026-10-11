part of '../player_immersive_controls.dart';

/// The controls' sizes and margins: the same layout for a pointer and for
/// a finger, which gets larger targets and less margin, since a phone's
/// screen is small and its edges are at the hands.
class _ControlsMetrics {
  const _ControlsMetrics._({
    required this.sideInset,
    required this.topInset,
    required this.bottomInset,
    required this.backButton,
    required this.backButtonInset,
    required this.barButton,
    required this.barButtonInset,
    required this.seekButton,
    required this.playBox,
    required this.playGlyph,
    required this.centerGap,
    required this.touch,
  });

  static const _pointer = _ControlsMetrics._(
    sideInset: 48,
    topInset: 20,
    bottomInset: 24,
    backButton: 44,
    backButtonInset: 12,
    barButton: Size(44, 40),
    barButtonInset: 14,
    seekButton: 60,
    playBox: 96,
    playGlyph: 42,
    centerGap: 48,
    touch: false,
  );

  static const _touch = _ControlsMetrics._(
    sideInset: 24,
    topInset: 12,
    bottomInset: 12,
    backButton: 48,
    backButtonInset: 12,
    barButton: Size(48, 48),
    barButtonInset: 14,
    seekButton: 56,
    playBox: 72,
    playGlyph: 32,
    centerGap: 40,
    touch: true,
  );

  static _ControlsMetrics of(PlayerInputMode input) => switch (input) {
    PlayerInputMode.pointer => _pointer,
    PlayerInputMode.touch => _touch,
  };

  /// The margin at the left and right of the video: the titles, the
  /// timeline, the notice and the offers keep to it.
  final double sideInset;
  final double topInset;
  final double bottomInset;

  final double backButton;

  /// How far the back arrow's glyph sits inside its button, so the glyph,
  /// not the button, lines up with the titles.
  final double backButtonInset;
  final Size barButton;

  /// The same for the last bar button and the offers above it.
  final double barButtonInset;
  final double seekButton;
  final double playBox;
  final double playGlyph;

  /// Between play and the ±10 s buttons.
  final double centerGap;

  /// Sized for a finger: titles at most `headlineSmall`, no volume and no
  /// full-screen button.
  final bool touch;

  /// The margins from the screen's edges, past the system's [safe] area
  /// (a camera cutout at the side of a phone in landscape).
  EdgeInsets insets(EdgeInsets safe) => EdgeInsets.fromLTRB(
    sideInset + safe.left,
    topInset + safe.top,
    sideInset + safe.right,
    bottomInset + safe.bottom,
  );
}
