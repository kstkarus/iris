import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/search_field.dart';

/// A search field with one action (sort, filters) on the same row: a
/// labelled button on wide windows, a square icon button on narrow ones.
///
/// [actionActive] marks an action whose settings differ from the default,
/// so a narrowed list never looks complete by accident.
class SearchToolbar extends StatelessWidget {
  const SearchToolbar({
    required this.searchField,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
    required this.isWide,
    this.actionActive = false,
    this.trailingAction,
    this.actionCount = 0,
    super.key,
  });

  static const cancelButtonKey = SearchField.cancelButtonKey;

  final SearchField searchField;
  final PixelGlyph actionIcon;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isWide;
  final bool actionActive;
  final Widget? trailingAction;
  final int actionCount;

  @override
  Widget build(BuildContext context) {
    final marker = actionCount > 0
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            color: Theme.of(context).colorScheme.onSurface,
            child: Text(
              '$actionCount',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.surface,
              ),
            ),
          )
        : actionActive
        ? const _ActiveMarker()
        : null;
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
            clipBehavior: Clip.none,
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
              if (marker != null)
                Positioned(
                  top: actionCount > 0 ? -10 : 8,
                  right: actionCount > 0 ? -8 : 8,
                  child: marker,
                ),
            ],
          );

    final trailing = trailingAction;
    if (trailing != null && !isWide) {
      // The field keeps room for Search, text and Clear beside two buttons.
      const minimumWidth = SearchField.height * 5 + 16;
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= minimumWidth) {
            return _row(action, trailing: trailing);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(action),
              const SizedBox(height: 8),
              Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
            ],
          );
        },
      );
    }
    return _row(action, trailing: trailing);
  }

  Widget _row(Widget action, {Widget? trailing}) {
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
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
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
