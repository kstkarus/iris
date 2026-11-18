import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/active_layer.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// Search field with a Clear button once something is typed.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.focusNode,
    this.onSubmitted,
    this.onCancel,
    super.key,
  });

  static const clearButtonKey = Key('search_field_clear_button');
  static const cancelButtonKey = Key('search_toolbar_cancel_button');

  /// Shared with the buttons next to the field.
  static const height = 48.0;

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rule = DetailLayout.ruleColor(scheme);
    final sans = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: rule),
    );
    final anim = motionDuration(context, const Duration(milliseconds: 160));
    Widget fadeSwitch(Widget child) => anim == Duration.zero
        ? child
        : AnimatedSwitcher(
            duration: anim,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.center,
              children: ActiveLayer.switcherChildren(
                currentChild,
                previousChildren,
              ),
            ),
            child: child,
          );

    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: sans,
        decoration: InputDecoration(
          filled: true,
          fillColor: scheme.surfaceContainerLow,
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: scheme.onSurface),
          ),
          hintText: hintText,
          hintStyle: sans?.copyWith(color: scheme.onSurfaceVariant),
          prefixIcon: fadeSwitch(
            onCancel == null
                ? PixelIcon(
                    PixelGlyph.search,
                    key: const ValueKey('search'),
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  )
                : IconButton(
                    key: cancelButtonKey,
                    tooltip: AppLocalizations.of(context).searchCancelButton,
                    onPressed: onCancel,
                    icon: const PixelIcon(PixelGlyph.arrowLeft, size: 16),
                  ),
          ),
          suffixIconConstraints: const BoxConstraints(minHeight: height),
          suffixIcon: fadeSwitch(
            value.text.isEmpty
                ? const SizedBox.shrink(key: ValueKey('empty'))
                : IconButton(
                    key: clearButtonKey,
                    tooltip: AppLocalizations.of(context).searchClearTooltip,
                    icon: const PixelIcon(PixelGlyph.close, size: 14),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          constraints: const BoxConstraints.tightFor(height: height),
        ),
      ),
    );
  }
}
