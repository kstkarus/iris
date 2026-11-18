import 'package:flutter/widgets.dart';

import 'package:iris/shared/widgets/dither_switcher.dart';

/// Swaps a state glyph (play/pause, mute, full screen) cell by cell via
/// [DitherSwitcher], or at once when reduced motion is enabled. The [child]'s
/// key tells the states apart.
class PlayerGlyphSwitcher extends StatelessWidget {
  const PlayerGlyphSwitcher({required this.child, super.key});

  static const _duration = Duration(milliseconds: 220);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DitherSwitcher(duration: _duration, child: child);
  }
}
