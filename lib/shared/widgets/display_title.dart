import 'package:flutter/material.dart';

/// A headline set as large as the space allows: the biggest size up to
/// [maxSize] at which [text] wraps into at most [maxLines] lines without
/// breaking a word, and never below [minSize].
///
/// This is the one big voice of a page. Everything around it stays small,
/// so the contrast in scale carries the hierarchy.
class DisplayTitle extends StatelessWidget {
  const DisplayTitle(
    this.text, {
    required this.maxSize,
    this.minSize = 28,
    this.maxLines = 3,
    this.color,
    super.key,
  });

  final String text;
  final double maxSize;
  final double minSize;
  final int maxLines;
  final Color? color;

  /// The display style at [size]: tight lines and tracking that tightens
  /// with size, as large type needs.
  static TextStyle styleAt(TextStyle base, double size) =>
      base.copyWith(fontSize: size, height: 1.02, letterSpacing: -0.035 * size);

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(
      context,
    ).textTheme.displayLarge!.copyWith(color: color);
    final textScaler = MediaQuery.textScalerOf(context);
    return Semantics(
      header: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = fitDisplaySize(
            text,
            base: base,
            width: constraints.maxWidth,
            maxSize: maxSize,
            minSize: minSize,
            maxLines: maxLines,
            textScaler: textScaler,
          );
          return Text(text, style: styleAt(base, size));
        },
      ),
    );
  }
}

/// See [DisplayTitle].
double fitDisplaySize(
  String text, {
  required TextStyle base,
  required double width,
  required double maxSize,
  required double minSize,
  required int maxLines,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  if (!width.isFinite || width <= 0) return minSize;
  final longestWord = text
      .split(RegExp(r'\s+'))
      .fold(
        '',
        (longest, word) => word.length > longest.length ? word : longest,
      );

  bool fits(double size) {
    final style = DisplayTitle.styleAt(base, size);
    final whole = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: maxLines,
    )..layout(maxWidth: width);
    final word = TextPainter(
      text: TextSpan(text: longestWord, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final result = !whole.didExceedMaxLines && word.width <= width;
    whole.dispose();
    word.dispose();
    return result;
  }

  var size = maxSize;
  while (size > minSize && !fits(size)) {
    size *= 0.92;
  }
  return size < minSize ? minSize : size.floorToDouble();
}
