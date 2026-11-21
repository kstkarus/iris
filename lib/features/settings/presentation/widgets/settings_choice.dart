import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:iris/features/settings/presentation/widgets/settings_row.dart';
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/widgets/checked_menu_item.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/focusable_list_row.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_choice.dart';

class SettingsMenuChoice<T> extends StatefulWidget {
  const SettingsMenuChoice({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  State<SettingsMenuChoice<T>> createState() => _SettingsMenuChoiceState<T>();
}

class _SettingsMenuChoiceState<T> extends State<SettingsMenuChoice<T>> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = SettingsRow.labelStyle(theme);
    final selected = widget.options.firstWhere(
      (option) => option.value == widget.selected,
    );
    return MenuAnchor(
      childFocusNode: _focusNode,
      style: const MenuStyle(alignment: AlignmentDirectional.bottomEnd),
      alignmentOffset: const Offset(0, 2),
      menuChildren: [
        for (final option in widget.options)
          CheckedMenuItem(
            checked: option.value == widget.selected,
            onPressed: () {
              if (option.value != widget.selected) AppHaptics.selection();
              widget.onSelected(option.value);
            },
            child: Text(
              option.label,
              style: const TextStyle(fontFamily: DetailLayout.sansFont),
            ),
          ),
      ],
      builder: (context, controller, child) => Semantics(
        button: true,
        expanded: controller.isOpen,
        child: FocusableListRow(
          focusNode: _focusNode,
          onTap: controller.toggle,
          child: child!,
        ),
      ),
      child: SettingsRow(
        action: Padding(
          padding: SettingsRow.contentPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  selected.label,
                  textAlign: TextAlign.end,
                  style: style?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 8),
              PixelIcon(
                PixelGlyph.expand,
                size: 10,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
        child: Text(widget.label, style: style),
      ),
    );
  }
}

class SettingsAppearanceChoice<T> extends StatelessWidget {
  const SettingsAppearanceChoice({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 480.0);
        final textWidth =
            (width - 2) / options.length -
            2 * SegmentedChoice.horizontalCellPadding;
        final style = SegmentedChoice.labelStyle(theme);
        final direction = Directionality.of(context);
        final scaler = MediaQuery.textScalerOf(context);
        final fits = options.every(
          (option) =>
              TextPainter.computeWidth(
                text: TextSpan(text: option.label, style: style),
                textDirection: direction,
                textScaler: scaler,
                maxLines: 1,
              ) <=
              textWidth,
        );
        if (!fits) {
          return SettingsMenuChoice<T>(
            label: label,
            options: options,
            selected: selected,
            onSelected: onSelected,
          );
        }
        return SettingsRow(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: SettingsRow.labelStyle(theme)),
              const SizedBox(height: 8),
              SizedBox(
                width: width,
                child: SegmentedChoice<T>(
                  options: options,
                  selected: selected,
                  onSelected: onSelected,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
