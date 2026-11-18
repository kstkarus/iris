import 'package:flutter/material.dart';

/// A headline set as large as the space allows: the biggest size up to
/// [maxSize] at which [text] wraps into at most [maxLines] lines without
/// breaking a word, and never below [minSize]. A bounded height from the
/// parent is a limit too.
/// At [minSize], multi-line titles can wrap further. Single-line titles use
/// an ellipsis when they do not fit.
/// With [snapStep], [maxSize] is rounded to the nearest grid multiple.
///
/// This is the one big voice of a page. Everything around it stays small,
/// so the contrast in scale carries the hierarchy.
class DisplayTitle extends StatelessWidget {
  const DisplayTitle(
    this.text, {
    required this.maxSize,
    this.minSize = 28,
    this.preferredMinSize,
    this.maxLines = 3,
    this.fontFamily,
    this.respectTextScale = true,
    this.snapStep,
    this.fallbackStyleAt,
    super.key,
  });

  final String text;
  final double maxSize;
  final double minSize;
  final double? preferredMinSize;
  final int maxLines;
  final String? fontFamily;
  final bool respectTextScale;
  final double? snapStep;
  final TextStyle Function(TextStyle base, double size)? fallbackStyleAt;

  /// The display style at [size]: tight lines and tracking that tightens
  /// with size, as large type needs.
  static TextStyle styleAt(TextStyle base, double size) =>
      base.copyWith(fontSize: size, height: 1.02, letterSpacing: -0.035 * size);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final base = textTheme.displayLarge!.copyWith(fontFamily: fontFamily);
    final textScaler = respectTextScale
        ? MediaQuery.textScalerOf(context)
        : TextScaler.noScaling;
    return Semantics(
      header: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fallback = fallbackStyleAt;
          final primaryMin = fallback == null
              ? minSize
              : (preferredMinSize ?? minSize)
                    .clamp(minSize, maxSize)
                    .toDouble();
          final size = fitDisplaySize(
            text,
            base: base,
            width: constraints.maxWidth,
            maxSize: maxSize,
            minSize: primaryMin,
            preferredMinSize: preferredMinSize,
            maxLines: maxLines,
            maxHeight: constraints.maxHeight,
            textScaler: textScaler,
            snapStep: snapStep,
          );
          final TextStyle style;
          if (fallback != null && size == null) {
            final fallbackMax = (preferredMinSize ?? maxSize)
                .clamp(minSize, maxSize)
                .toDouble();
            final fallbackSize = fitDisplaySize(
              text,
              base: base,
              width: constraints.maxWidth,
              maxSize: fallbackMax,
              minSize: minSize,
              maxLines: maxLines,
              maxHeight: constraints.maxHeight,
              textScaler: textScaler,
              styleBuilder: fallback,
            );
            style = fallback(base, fallbackSize ?? minSize);
          } else {
            style = styleAt(base, size ?? minSize);
          }
          final singleLine = maxLines == 1;
          return Text(
            text,
            maxLines: singleLine ? 1 : null,
            overflow: singleLine ? TextOverflow.ellipsis : TextOverflow.clip,
            style: style,
            textScaler: textScaler,
          );
        },
      ),
    );
  }
}

/// See [DisplayTitle]. Returns null when even the smallest text cannot fit.
double? fitDisplaySize(
  String text, {
  required TextStyle base,
  required double width,
  required double maxSize,
  required double minSize,
  double? preferredMinSize,
  required int maxLines,
  double maxHeight = double.infinity,
  TextScaler textScaler = TextScaler.noScaling,
  double? snapStep,
  TextStyle Function(TextStyle base, double size)? styleBuilder,
}) {
  if (!width.isFinite || width <= 0) return null;
  final resolveStyle = styleBuilder ?? DisplayTitle.styleAt;
  final longestWord = text
      .split(RegExp(r'\s+'))
      .fold(
        '',
        (longest, word) => word.length > longest.length ? word : longest,
      );

  bool fits(double size) {
    final style = resolveStyle(base, size);
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
    final result =
        !whole.didExceedMaxLines &&
        whole.height <= maxHeight &&
        word.width <= width;
    whole.dispose();
    word.dispose();
    return result;
  }

  final rawMin = preferredMinSize != null && preferredMinSize > minSize
      ? preferredMinSize
      : minSize;
  final effectiveMin = rawMin > maxSize && maxSize > minSize ? maxSize : rawMin;

  double? fitContinuous(double floor, {double? startSize}) {
    var size = startSize ?? maxSize;
    while (size >= floor) {
      if (fits(size)) {
        final floored = size.floorToDouble();
        return floored >= floor ? floored : size;
      }
      size *= 0.92;
    }
    return fits(floor) ? floor : null;
  }

  if (snapStep != null && snapStep > 0) {
    for (var k = (maxSize / snapStep).round(); k >= 1; k--) {
      final candidate = k * snapStep;
      if (candidate < effectiveMin) break;
      if (fits(candidate)) return candidate;
    }
    if (effectiveMin > minSize) {
      final below = effectiveMin - 0.01;
      return fitContinuous(
        minSize,
        startSize: below < maxSize ? below : maxSize,
      );
    }
    return null;
  }

  if (effectiveMin > minSize) {
    final preferred = fitContinuous(effectiveMin);
    if (preferred != null) return preferred;
  }
  return fitContinuous(minSize);
}

/// How tall [text] is set at [size] in [width], every line counted: what a
/// [DisplayTitle] needs at its smallest.
double displayTitleHeight(
  String text, {
  required TextStyle base,
  required double size,
  required double width,
  TextScaler textScaler = TextScaler.noScaling,
  TextStyle Function(TextStyle base, double size)? styleBuilder,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: (styleBuilder ?? DisplayTitle.styleAt)(base, size),
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout(maxWidth: width);
  final height = painter.height;
  painter.dispose();
  return height;
}
