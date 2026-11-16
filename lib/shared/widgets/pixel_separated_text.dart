import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/detail_layout.dart';

const _separatorToken = ' · ';

/// Metadata separated by small squares, with readable punctuation for speech.
class PixelSeparatedText extends StatelessWidget {
  const PixelSeparatedText(
    this.text, {
    this.style,
    this.sansStyle,
    this.monoStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.textAlign,
    this.softWrap,
    super.key,
  }) : _parts = null,
       _spans = null;

  const PixelSeparatedText.parts(
    List<String> parts, {
    this.style,
    this.sansStyle,
    this.monoStyle,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.textAlign,
    this.softWrap,
    super.key,
  }) : text = null,
       _parts = parts,
       _spans = null;

  const PixelSeparatedText.spans(
    List<InlineSpan> spans, {
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.textAlign,
    this.softWrap,
    super.key,
  }) : text = null,
       _parts = null,
       _spans = spans,
       sansStyle = null,
       monoStyle = null;

  final String? text;
  final List<String>? _parts;
  final List<InlineSpan>? _spans;
  final TextStyle? style;
  final TextStyle? sansStyle;
  final TextStyle? monoStyle;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  static List<String> splitSegments(String value) => [
    for (final part in value.split(_separatorToken))
      if (part.isNotEmpty) part,
  ];

  @override
  Widget build(BuildContext context) {
    final textStyle = sansStyle ?? style;
    final spans =
        _spans ??
        <InlineSpan>[
          for (final part in (_parts ?? [text ?? '']).expand(splitSegments))
            if (monoStyle == null)
              TextSpan(text: part)
            else
              DetailLayout.mixedDataSpan(
                part,
                sansStyle: textStyle,
                monoStyle: monoStyle,
              ),
        ];
    final color =
        DefaultTextStyle.of(context).style.merge(textStyle).color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    return Text.rich(
      TextSpan(
        children: [
          for (final (index, span) in spans.indexed) ...[
            if (index > 0) _separator(color.withValues(alpha: color.a * 0.65)),
            span,
          ],
        ],
      ),
      style: textStyle,
      semanticsLabel: spans
          .map((span) => span.toPlainText(includePlaceholders: false))
          .join(', '),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }
}

WidgetSpan _separator(Color color) => WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox.square(dimension: 2, child: ColoredBox(color: color)),
    ),
  ),
);
