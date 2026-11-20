import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/shared/models/details_description.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/tap_row.dart';

class DetailsDescriptionText extends StatelessWidget {
  const DetailsDescriptionText({required this.description, super.key});

  final DetailsDescription description;

  @override
  Widget build(BuildContext context) {
    final DetailsDescription(:text, :characterLinks) = description;
    final style = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontFamily: DetailLayout.sansFont);
    if (characterLinks.isEmpty) return Text(text.trim(), style: style);

    final children = <InlineSpan>[];
    final linkStyle = style?.copyWith(decoration: TextDecoration.underline);
    var offset = 0;
    for (final (:start, :end, :characterId) in characterLinks) {
      if (offset < start) {
        children.add(TextSpan(text: text.substring(offset, start)));
      }
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Semantics(
            link: true,
            child: TapRow(
              onTap: () => context.pushNamed(
                'character',
                pathParameters: {'id': characterId},
              ),
              child: Text(
                text.substring(start, end),
                style: linkStyle,
                // WidgetSpan already applies the paragraph's text scaling.
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      );
      offset = end;
    }
    if (offset < text.length) {
      children.add(TextSpan(text: text.substring(offset)));
    }

    return Text.rich(TextSpan(children: children), style: style);
  }
}
