import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/search_field.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

/// A search field with one action (sort, filters) on the same row: a
/// labelled button on wide windows, a square icon button on narrow ones.
///
/// [actionActive] marks an action whose settings differ from the default,
/// so a narrowed list never looks complete by accident. With [onCancel],
/// a text button at the end leaves the search.
class SearchToolbar extends StatelessWidget {
  const SearchToolbar({
    required this.searchField,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
    required this.isWide,
    this.actionActive = false,
    this.onCancel,
    super.key,
  });

  static const cancelButtonKey = Key('search_toolbar_cancel_button');

  final SearchField searchField;
  final PixelGlyph actionIcon;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isWide;
  final bool actionActive;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final marker = actionActive ? const _ActiveMarker() : null;
    final Widget action = isWide
        ? OutlinedButton.icon(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, SearchField.height),
            ),
            icon: PixelIcon(actionIcon, size: 16),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(actionLabel),
                if (marker != null) ...[const SizedBox(width: 8), marker],
              ],
            ),
          )
        : Stack(
            children: [
              IconButton.filledTonal(
                tooltip: actionLabel,
                onPressed: onAction,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(SearchField.height),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHigh,
                ),
                icon: PixelIcon(actionIcon, size: 18),
              ),
              if (marker != null) Positioned(top: 8, right: 8, child: marker),
            ],
          );

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
        const SizedBox(width: 8),
        action,
        if (onCancel case final onCancel?) ...[
          const SizedBox(width: 4),
          TextButton(
            key: cancelButtonKey,
            onPressed: onCancel,
            child: Text(AppLocalizations.of(context).searchCancelButton),
          ),
        ],
      ],
    );
  }
}

class _ActiveMarker extends StatelessWidget {
  const _ActiveMarker();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 6,
      child: ColoredBox(color: Theme.of(context).colorScheme.onSurface),
    );
  }
}
