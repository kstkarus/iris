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
    this.trailingAction,
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
  final Widget? trailingAction;
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

    if (trailingAction != null && !isWide) {
      final theme = Theme.of(context);
      final buttonStyle = theme.textButtonTheme.style;
      final label = TextPainter(
        text: TextSpan(
          text: AppLocalizations.of(context).searchCancelButton,
          style:
              buttonStyle?.textStyle?.resolve({}) ?? theme.textTheme.labelLarge,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final padding = buttonStyle?.padding?.resolve({})?.horizontal ?? 16;
      final cancelWidth = (label.width + padding).clamp(48.0, double.infinity);
      label.dispose();
      // Reserve room for Clear and Cancel before focusing the field, so the
      // new action does not squeeze out the existing search controls.
      final minimumWidth = SearchField.height * 4 + 20 + cancelWidth;
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= minimumWidth) {
            return _row(context, action);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row(context, action, includeTrailing: false),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: trailingAction,
              ),
            ],
          );
        },
      );
    }
    return _row(context, action);
  }

  Widget _row(
    BuildContext context,
    Widget action, {
    bool includeTrailing = true,
  }) {
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
        if (includeTrailing && trailingAction != null) ...[
          const SizedBox(width: 8),
          trailingAction!,
        ],
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
