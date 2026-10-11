import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/pixel_icon.dart';

/// A menu item with a check before it when [checked]; unchecked items keep
/// the check's room, so the labels line up.
class CheckedMenuItem extends StatelessWidget {
  const CheckedMenuItem({
    required this.checked,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final bool checked;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      onPressed: onPressed,
      leadingIcon: SizedBox.square(
        dimension: 14,
        child: checked ? const PixelIcon(PixelGlyph.check, size: 14) : null,
      ),
      child: child,
    );
  }
}

extension MenuControllerToggle on MenuController {
  void toggle() => isOpen ? close() : open();
}
