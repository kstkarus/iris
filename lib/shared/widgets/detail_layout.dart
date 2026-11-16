import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/display_title.dart';
import 'package:iris/shared/widgets/headline_anchor.dart';
import 'package:iris/shared/widgets/headline_column.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// Shared surface styling and typographic contract for editorial detail pages
/// (anime details, character details).
abstract final class DetailLayout {
  static const sansFont = 'Medeo Sans';
  static const monoFont = 'Medeo Mono';
  static const pixelFont = 'Medeo Pixel Grid';

  static const double pixelTitleMinSize = 24;
  static const double largeTextScale = 1.35;

  static final _numericTokenPattern = RegExp(r'\d+(?:[:.,/]\d+)*');

  /// Logical font-size step where one `38`-UPM grid cell of [pixelFont] maps to
  /// whole physical device pixels (`fontSize * 0.038 * dpr = k`).
  static double pixelGridStep(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return (1000 / 38) / (dpr > 0 ? dpr : 1.0);
  }

  static bool isLargeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) >= largeTextScale;

  /// Higher-contrast hairline color so card edges and internal grid rules
  /// hold up cleanly on both dark and light backgrounds.
  static Color ruleColor(ColorScheme scheme) =>
      Color.lerp(scheme.outlineVariant, scheme.outline, 0.45)!;

  static BoxDecoration cardDecoration(
    ColorScheme scheme, {
    Color? background,
  }) => BoxDecoration(
    color: background ?? scheme.surfaceContainerLow,
    border: Border.all(color: ruleColor(scheme)),
  );

  /// Section title style in solid SemiBold Mono (`18 px`), compensating Mono's
  /// `0.6 em` space glyph with negative `wordSpacing`.
  static TextStyle sectionTitleStyle(ThemeData theme) {
    final base = theme.textTheme.titleLarge ?? const TextStyle();
    return base.copyWith(
      fontFamily: monoFont,
      fontSize: 18,
      height: 1.25,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      wordSpacing: -4.8,
      color: theme.colorScheme.onSurface,
    );
  }

  /// Proportional fallback when no pixel title fits above [pixelTitleMinSize].
  /// The title block may grow past the cover rather than clip either name.
  static TextStyle fallbackTitleStyle(TextStyle base, double size) =>
      base.copyWith(
        fontFamily: sansFont,
        fontSize: size,
        height: 1.12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.015 * size,
      );

  /// Splits [text] so numeric/time tokens render in [monoStyle] with
  /// `tabularFigures` and surrounding words render in [sansStyle].
  static TextSpan mixedDataSpan(
    String text, {
    required TextStyle? sansStyle,
    required TextStyle? monoStyle,
  }) {
    final resolvedSans = sansStyle?.copyWith(fontFamily: sansFont);
    final resolvedMono = monoStyle?.copyWith(
      fontFamily: monoFont,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _numericTokenPattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, match.start),
            style: resolvedSans,
          ),
        );
      }
      spans.add(TextSpan(text: match.group(0), style: resolvedMono));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: resolvedSans));
    }
    return TextSpan(
      style: resolvedSans,
      children: spans.isEmpty ? [TextSpan(text: text)] : spans,
    );
  }
}

/// Renders a telemetry or mixed metadata string with words in `Medeo Sans` and
/// numeric/time runs in tabular `Medeo Mono`.
class MixedDataText extends StatelessWidget {
  const MixedDataText(
    this.text, {
    required this.sansStyle,
    this.monoStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  final String text;
  final TextStyle? sansStyle;
  final TextStyle? monoStyle;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      DetailLayout.mixedDataSpan(
        text,
        sansStyle: sansStyle,
        monoStyle: monoStyle ?? sansStyle,
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Section wrapper applying [DetailLayout.sectionTitleStyle] without uppercase
/// or `>>` prefixes.
class DetailSection extends StatelessWidget {
  const DetailSection({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => LabeledSection(
    label: label,
    labelStyle: DetailLayout.sectionTitleStyle(Theme.of(context)),
    uppercase: false,
    showPrefix: false,
    child: child,
  );
}

/// Primary title block anchored for the collapsing app-bar title transition,
/// pairing `Medeo Pixel Grid` display sizing with a `Medeo Sans` fallback and
/// optional [HeadlineColumn] height budget.
class DetailHeroTitles extends StatelessWidget {
  const DetailHeroTitles({
    required this.title,
    required this.maxSize,
    required this.minSize,
    this.subtitle,
    this.maxLines = 4,
    this.maxHeight,
    super.key,
  });

  final String title;
  final String? subtitle;
  final double maxSize;
  final double minSize;
  final int maxLines;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final clampedScale = textScale.clamp(1.0, 1.5);
    final heroMaxSize = (maxSize * clampedScale).roundToDouble();
    final heroMinSize = (minSize * textScale.clamp(1.0, 1.25)).roundToDouble();
    final pixelMinSize = DetailLayout.pixelTitleMinSize * clampedScale;
    final headline = HeadlineAnchor(
      child: DisplayTitle(
        title,
        fontFamily: DetailLayout.pixelFont,
        maxSize: heroMaxSize,
        minSize: heroMinSize,
        preferredMinSize: pixelMinSize,
        maxLines: maxLines,
        respectTextScale: false,
        snapStep: DetailLayout.pixelGridStep(context),
        fallbackStyleAt: DetailLayout.fallbackTitleStyle,
      ),
    );
    final sub = subtitle?.trim() ?? '';
    final subtitleWidget = sub.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              sub,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: DetailLayout.sansFont,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          )
        : const SizedBox.shrink();

    if (maxHeight != null && !DetailLayout.isLargeText(context)) {
      return LayoutBuilder(
        builder: (context, constraints) => HeadlineColumn(
          height: maxHeight!,
          minHeadlineHeight: displayTitleHeight(
            title,
            base: Theme.of(context).textTheme.displayLarge!,
            size: heroMinSize,
            width: constraints.maxWidth,
            styleBuilder: DetailLayout.fallbackTitleStyle,
          ),
          headline: headline,
          rest: subtitleWidget,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [headline, if (sub.isNotEmpty) subtitleWidget],
    );
  }
}

/// Visible above-the-fold retry card when full details fail to load on top of
/// a preview.
class DetailRetryBanner extends StatelessWidget {
  const DetailRetryBanner({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: DetailLayout.cardDecoration(theme.colorScheme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: InlineRetry(
          message: message,
          onRetry: onRetry,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: DetailLayout.sansFont,
          ),
        ),
      ),
    );
  }
}
