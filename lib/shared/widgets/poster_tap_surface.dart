import 'package:flutter/material.dart';

import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';

/// Interactive wrapper for vertical poster cards (catalog, characters,
/// download gallery).
///
/// Unlike list rows, vertical poster cards do not paint a flat rectangular
/// gray hover slab behind their text; instead they switch to a click cursor
/// and pass [hovered] / [focused] to [builder] so the poster frame itself
/// responds cleanly.
class PosterTapSurface extends StatefulWidget {
  const PosterTapSurface({
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.inkKey,
    super.key,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Key? inkKey;
  final Widget Function(BuildContext context, bool hovered, bool focused)
  builder;

  @override
  State<PosterTapSurface> createState() => _PosterTapSurfaceState();
}

class _PosterTapSurfaceState extends State<PosterTapSurface> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null || widget.onLongPress != null;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: widget.inkKey,
        enableFeedback: widget.onLongPress == null,
        mouseCursor: interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onHover: interactive
            ? (hovered) {
                if (_hovered != hovered) setState(() => _hovered = hovered);
              }
            : null,
        onFocusChange: (focused) {
          final showFocus =
              focused &&
              FocusManager.instance.highlightMode ==
                  FocusHighlightMode.traditional;
          if (_focused != showFocus) setState(() => _focused = showFocus);
        },
        child: widget.builder(context, _hovered, _focused),
      ),
    );
  }
}

/// Frames a poster with a hairline border that brightens on hover/focus while
/// keeping optional [overlay] widgets (e.g., list badges or progress bars)
/// anchored.
class PosterHoverFrame extends StatelessWidget {
  const PosterHoverFrame({
    required this.poster,
    required this.hovered,
    required this.focused,
    this.overlay,
    super.key,
  });

  final Widget poster;
  final bool hovered;
  final bool focused;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final anim = motionDuration(context, const Duration(milliseconds: 160));
    final borderColor = focused
        ? scheme.onSurface
        : hovered
        ? scheme.onSurface.withValues(alpha: 0.75)
        : DetailLayout.ruleColor(scheme);

    return AnimatedContainer(
      duration: anim,
      curve: Curves.easeOutCubic,
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: borderColor, width: focused ? 2 : 1),
      ),
      child: Stack(children: [poster, ?overlay]),
    );
  }
}
