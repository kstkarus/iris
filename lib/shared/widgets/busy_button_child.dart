import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/pixel_noise.dart';

/// Paints Iris's ordered-dither sweep across the button's fill while [busy],
/// keeping the button's existing theme, border, and size intact.
ButtonStyle? busyButtonStyle({required bool busy, ButtonStyle? base}) {
  if (!busy) return base;
  const sweep = ButtonStyle(backgroundBuilder: _busyBackground);
  return base == null ? sweep : base.merge(sweep);
}

Widget _busyBackground(
  BuildContext context,
  Set<WidgetState> states,
  Widget? child,
) => Stack(
  fit: StackFit.passthrough,
  alignment: Alignment.center,
  children: [
    const Positioned.fill(child: IgnorePointer(child: PixelNoise.surface())),
    ?child,
  ],
);

/// The label of a button whose onPressed is null while [busy]. Pair with
/// [busyButtonStyle] so both fill and text sweep together.
class BusyButtonChild extends StatelessWidget {
  const BusyButtonChild(
    this.label, {
    required this.busy,
    this.busyLabel,
    this.semanticsLabel,
    this.busySemanticsLabel,
    super.key,
  });

  final String label;
  final bool busy;
  final String? busyLabel;
  final String? semanticsLabel;
  final String? busySemanticsLabel;

  @override
  Widget build(BuildContext context) {
    final busyLabel = this.busyLabel;
    final idle = Text(
      label,
      semanticsLabel: semanticsLabel,
      textAlign: TextAlign.center,
    );
    if (busyLabel == null && !busy) return idle;

    final progressText = Text(
      busyLabel ?? label,
      semanticsLabel: busySemanticsLabel ?? semanticsLabel,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
    );
    final progress = busy
        ? Semantics(
            liveRegion: true,
            child: PixelNoise.shimmer(child: progressText),
          )
        : progressText;
    if (busyLabel == null) return progress;

    // Size for both labels so starting the action cannot move the button.
    return IndexedStack(
      index: busy ? 1 : 0,
      alignment: Alignment.center,
      children: [idle, progress],
    );
  }
}
