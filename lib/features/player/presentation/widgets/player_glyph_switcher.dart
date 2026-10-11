import 'package:flutter/widgets.dart';

import 'package:iris/shared/utils/motion_duration.dart';

/// Cross-fades a state glyph (play/pause, mute, full screen) when the state
/// changes, or swaps it at once when the system asks for less motion. The
/// [child]'s key tells the states apart.
class PlayerGlyphSwitcher extends StatelessWidget {
  const PlayerGlyphSwitcher({required this.child, super.key});

  static const _duration = Duration(milliseconds: 150);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionDuration(context, _duration),
      child: child,
    );
  }
}
