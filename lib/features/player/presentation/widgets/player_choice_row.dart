import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/pixel_icon.dart';

/// A row of a list to choose one from, such as a track or a decoder: the
/// chosen row carries a check mark, which fades in where the choice moves.
class PlayerChoiceRow extends StatelessWidget {
  const PlayerChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
    super.key,
  });

  static const _checkFade = Duration(milliseconds: 160);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Quiet text before the check slot, such as a track's codec.
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detail = this.detail;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      // For assistive technology; the check mark shows it on screen, so the
      // title keeps its colour.
      selected: selected,
      selectedColor: scheme.onSurface,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (detail != null) ...[
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
          ],
          SizedBox.square(
            dimension: 18,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : _checkFade,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.6, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: selected
                  ? PixelIcon(
                      PixelGlyph.check,
                      key: const ValueKey(true),
                      size: 18,
                      color: scheme.onSurface,
                    )
                  : const SizedBox.shrink(key: ValueKey(false)),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
