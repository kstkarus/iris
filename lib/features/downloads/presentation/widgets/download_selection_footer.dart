import 'package:flutter/material.dart';

import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// Reveals a batch action from the bottom without moving the list's origin.
class DownloadSelectionFooter extends StatelessWidget {
  const DownloadSelectionFooter({
    required this.visible,
    required this.child,
    super.key,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: ExcludeFocus(
      excluding: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: visible ? 1 : 0),
          duration: motionDuration(context, const Duration(milliseconds: 200)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Offstage(
            offstage: value == 0,
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: value,
                child: Opacity(opacity: value, child: child),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: WindowSizeClass.of(context).isCompact
                    ? double.infinity
                    : null,
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
