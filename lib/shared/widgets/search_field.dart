import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/pixel_icon.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

/// Search field with a Clear button once something is typed.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.focusNode,
    super.key,
  });

  static const clearButtonKey = Key('search_field_clear_button');

  /// Shared with the buttons next to the field.
  static const height = 48.0;

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const PixelIcon(PixelGlyph.search, size: 16),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  key: clearButtonKey,
                  tooltip: AppLocalizations.of(context).searchClearTooltip,
                  icon: const PixelIcon(PixelGlyph.close, size: 14),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          constraints: const BoxConstraints.tightFor(height: height),
        ),
      ),
    );
  }
}
