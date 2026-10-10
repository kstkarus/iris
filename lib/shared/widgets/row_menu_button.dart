import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/pixel_icon.dart';

/// A list row's "⋯" menu. The row opens the same [controller] on a long
/// press or a right click; the menu ends where its button ends instead of
/// running to the window's edge.
class RowMenuButton extends StatelessWidget {
  const RowMenuButton({
    required this.controller,
    required this.tooltip,
    required this.menuChildren,
    this.semanticLabel,
    this.onOpenChanged,
    super.key,
  });

  /// Fixed, so the menu can be laid out from its button's end.
  static const width = 224.0;
  static const _buttonWidth = 48.0;

  final MenuController controller;
  final String tooltip;
  final List<Widget> menuChildren;

  /// What a screen reader says for the button, naming the row's item;
  /// [tooltip] when null.
  final String? semanticLabel;

  /// Lets the row show which item its open menu acts on.
  final ValueChanged<bool>? onOpenChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: controller,
      onOpen: () => onOpenChanged?.call(true),
      onClose: () => onOpenChanged?.call(false),
      alignmentOffset: const Offset(_buttonWidth - width, 0),
      // Otherwise the panel shrinks to its items inside the fixed width and
      // stops short of the button.
      crossAxisUnconstrained: false,
      style: const MenuStyle(
        minimumSize: WidgetStatePropertyAll(Size(width, 0)),
        maximumSize: WidgetStatePropertyAll(Size(width, double.infinity)),
      ),
      menuChildren: menuChildren,
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        return Semantics(
          label: semanticLabel ?? tooltip,
          button: true,
          excludeSemantics: true,
          onTap: toggle,
          child: IconButton(
            tooltip: tooltip,
            icon: const PixelIcon(PixelGlyph.more, size: 18),
            onPressed: toggle,
          ),
        );
      },
    );
  }
}
