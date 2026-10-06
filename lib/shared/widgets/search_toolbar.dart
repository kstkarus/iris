import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/search_field.dart';

/// A search field with one action (sort, filters) of the same height: side
/// by side on wide windows, the action under the field otherwise.
class SearchToolbar extends StatelessWidget {
  const SearchToolbar({
    required this.searchField,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
    required this.isWide,
    super.key,
  });

  final SearchField searchField;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final action = OutlinedButton.icon(
      onPressed: onAction,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, SearchField.height),
      ),
      icon: Icon(actionIcon),
      label: Text(actionLabel),
    );

    if (isWide) {
      return Row(
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AdaptiveContentWidth.form,
              ),
              child: searchField,
            ),
          ),
          const SizedBox(width: 12),
          action,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [searchField, const SizedBox(height: 12), action],
    );
  }
}
