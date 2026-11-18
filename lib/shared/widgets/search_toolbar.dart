import 'package:flutter/material.dart';

import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
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
    final anim = motionDuration(context, const Duration(milliseconds: 160));
    final countMarker = actionCount > 0
        ? Container(
            key: ValueKey('count_$actionCount'),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            color: Theme.of(context).colorScheme.onSurface,
            child: Text(
              '$actionCount',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.surface,
              ),
            ),
          )
        : null;
    final activeMarker = actionCount == 0 && actionActive
        ? const _ActiveMarker(key: ValueKey('active'))
        : null;
    final wideMarker = countMarker ?? activeMarker;
    final scheme = Theme.of(context).colorScheme;
    final rule = DetailLayout.ruleColor(scheme);
    final Widget wideBadge = anim == Duration.zero
        ? wideMarker == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: wideMarker,
                )
        : AnimatedSize(
            duration: anim,
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: anim,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: wideMarker == null
                  ? const SizedBox.shrink(key: ValueKey('no_marker'))
                  : Padding(
                      key: ValueKey('marker_${actionCount}_$actionActive'),
                      padding: const EdgeInsets.only(left: 8),
                      child: wideMarker,
                    ),
            ),
          );
    final iconColor = actionActive
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.85);
    final Widget action = isWide
        ? OutlinedButton.icon(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, SearchField.height),
              backgroundColor: scheme.surfaceContainerLow,
              side: BorderSide(color: rule),
            ),
            icon: PixelIcon(actionIcon, size: 16, color: iconColor),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text(actionLabel), wideBadge],
            ),
          )
        : Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton.outlined(
                tooltip: actionLabel,
                onPressed: onAction,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(SearchField.height),
                  backgroundColor: scheme.surfaceContainerLow,
                  side: BorderSide(color: rule),
                ),
                icon: PixelIcon(actionIcon, size: 16, color: iconColor),
              ),
              Positioned(
                top: -10,
                right: -8,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: anim,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child:
                        countMarker ??
                        const SizedBox.shrink(key: ValueKey('no_count')),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(
                  child: AnimatedSwitcher(
                    duration: anim,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child:
                        activeMarker ??
                        const SizedBox.shrink(key: ValueKey('no_active')),
                  ),
                ),
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
  const _ActiveMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 6,
      child: ColoredBox(color: Theme.of(context).colorScheme.onSurface),
    );
  }
}
