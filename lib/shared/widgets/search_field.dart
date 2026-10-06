import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

/// Search field with a Clear button once something is typed.
class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    super.key,
  });

  static const clearButtonKey = Key('search_field_clear_button');

  /// Shared with the buttons next to the field.
  static const height = 48.0;

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  key: clearButtonKey,
                  tooltip: AppLocalizations.of(context).searchClearTooltip,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          constraints: const BoxConstraints.tightFor(height: height),
        ),
      ),
    );
  }
}
