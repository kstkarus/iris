import 'package:flutter/material.dart';

/// One option of a [SegmentedChoice].
class SegmentedOption<T> {
  const SegmentedOption({
    required this.value,
    required this.label,
    this.text,
    this.textStyle,
    this.leading,
  });

  final T value;

  /// What the option is called; screen readers read it, and it is shown
  /// unless [text] stands in for it.
  final String label;

  /// Shown instead of [label], such as a sample of a text size.
  final String? text;
  final TextStyle? textStyle;

  /// Drawn before the text, such as a colour swatch.
  final Widget? leading;
}

/// A row of square cells for a choice of one, such as a size or a colour:
/// the chosen cell is filled, and the fill slides to a new choice.
///
/// It reads as one control, unlike a list of check boxes, so a choice of one
/// and a choice of several do not look alike.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  static const _height = 44.0;
  static const _slide = Duration(milliseconds: 220);

  final List<SegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _slide;
    final index = options.indexWhere((option) => option.value == selected);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: scheme.outline)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellWidth = constraints.maxWidth / options.length;
          return Stack(
            children: [
              for (var divider = 1; divider < options.length; divider++)
                Positioned(
                  left: divider * cellWidth - 0.5,
                  top: 0,
                  bottom: 0,
                  width: 1,
                  child: ColoredBox(color: scheme.outline),
                ),
              if (index >= 0)
                AnimatedPositioned(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  left: index * cellWidth,
                  top: 0,
                  bottom: 0,
                  width: cellWidth,
                  child: ColoredBox(color: scheme.onSurface),
                ),
              Material(
                type: MaterialType.transparency,
                child: Row(
                  children: [
                    for (final option in options)
                      Expanded(
                        child: _Cell(
                          option: option,
                          selected: option.value == selected,
                          height: _height,
                          duration: duration,
                          textStyle: textStyle,
                          onTap: () => onSelected(option.value),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Cell<T> extends StatelessWidget {
  const _Cell({
    required this.option,
    required this.selected,
    required this.height,
    required this.duration,
    required this.textStyle,
    required this.onTap,
  });

  final SegmentedOption<T> option;
  final bool selected;
  final double height;
  final Duration duration;
  final TextStyle? textStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final leading = option.leading;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: option.label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              // A long label in a narrow cell shrinks rather than wraps.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  style: (textStyle ?? const TextStyle())
                      .merge(option.textStyle)
                      .copyWith(
                        color: selected
                            ? scheme.surface
                            : scheme.onSurfaceVariant,
                      ),
                  // The label above names it; a sample like "Aa" would not.
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leading != null) ...[
                          leading,
                          const SizedBox(width: 6),
                        ],
                        Text(option.text ?? option.label, maxLines: 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
