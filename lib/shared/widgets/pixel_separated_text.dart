import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:iris/shared/widgets/detail_layout.dart';

const _separatorToken = ' · ';
const _separatorGap = 6.0;
const _dotSize = 2.0;

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
    this.cleanLineWrap = false,
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
    this.cleanLineWrap = false,
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
    this.cleanLineWrap = false,
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

  /// Omits separator squares at line breaks in wrapping metadata.
  final bool cleanLineWrap;

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
    final sepColor = color.withValues(alpha: color.a * 0.65);
    final semanticsLabel = spans
        .map((span) => span.toPlainText(includePlaceholders: false))
        .join(', ');

    if (cleanLineWrap &&
        spans.length > 1 &&
        maxLines == null &&
        softWrap != false &&
        overflow == TextOverflow.clip) {
      return Semantics(
        container: true,
        label: semanticsLabel,
        child: ExcludeSemantics(
          child: _SeparatedWrap(
            separatorColor: sepColor,
            children: [
              for (final span in spans)
                Text.rich(TextSpan(children: [span]), style: textStyle),
            ],
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          for (final (index, span) in spans.indexed) ...[
            if (index > 0) _separator(sepColor),
            span,
          ],
        ],
      ),
      style: textStyle,
      semanticsLabel: semanticsLabel,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }
}

class _SeparatedWrap extends MultiChildRenderObjectWidget {
  const _SeparatedWrap({required this.separatorColor, required super.children});

  final Color separatorColor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSeparatedWrap(separatorColor, Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSeparatedWrap renderObject,
  ) {
    renderObject
      ..separatorColor = separatorColor
      ..textDirection = Directionality.of(context);
  }
}

class _RenderSeparatedWrap extends RenderWrap {
  _RenderSeparatedWrap(this._separatorColor, TextDirection textDirection)
    : super(
        spacing: _separatorGap * 2 + _dotSize,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        textDirection: textDirection,
      );

  Color _separatorColor;
  set separatorColor(Color value) {
    if (_separatorColor == value) return;
    _separatorColor = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final dotPaint = Paint()..color = _separatorColor;
    RenderBox? previous;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final pd = child.parentData! as WrapParentData;
      if (previous != null) {
        final previousData = previous.parentData! as WrapParentData;
        // Children in the same run overlap vertically, even with different fonts.
        final sameRun =
            pd.offset.dy < previousData.offset.dy + previous.size.height &&
            previousData.offset.dy < pd.offset.dy + child.size.height;
        if (sameRun) {
          final gapStart = textDirection == TextDirection.rtl
              ? pd.offset.dx + child.size.width
              : previousData.offset.dx + previous.size.width;
          context.canvas.drawRect(
            Rect.fromLTWH(
              offset.dx + gapStart + _separatorGap,
              offset.dy + pd.offset.dy + (child.size.height - _dotSize) / 2,
              _dotSize,
              _dotSize,
            ),
            dotPaint,
          );
        }
      }
      previous = child;
    }
  }
}

WidgetSpan _separator(Color color) => WidgetSpan(
  alignment: PlaceholderAlignment.middle,
  child: ExcludeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: _separatorGap),
      child: SizedBox.square(
        dimension: _dotSize,
        child: ColoredBox(color: color),
      ),
    ),
  ),
);
