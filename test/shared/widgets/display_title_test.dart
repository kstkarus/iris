import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/display_title.dart';

void main() {
  const base = TextStyle(fontSize: 96, height: 1);

  test('keeps the largest size when the text fits', () {
    final size = fitDisplaySize(
      'Iris',
      base: base,
      width: 2000,
      maxSize: 120,
      minSize: 20,
      maxLines: 1,
    );

    expect(size, 120);
  });

  test('shrinks until the text fits the allowed lines', () {
    const text = 'Frieren Beyond Journeys End';
    final size = fitDisplaySize(
      text,
      base: base,
      width: 600,
      maxSize: 200,
      minSize: 10,
      maxLines: 2,
    );

    final painter = TextPainter(
      text: TextSpan(text: text, style: DisplayTitle.styleAt(base, size)),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 600);
    expect(size, lessThan(200));
    expect(painter.didExceedMaxLines, isFalse);
    painter.dispose();
  });

  test('never breaks the longest word', () {
    final size = fitDisplaySize(
      'Supercalifragilistic',
      base: base,
      width: 300,
      maxSize: 200,
      minSize: 4,
      maxLines: 3,
    );

    final painter = TextPainter(
      text: TextSpan(
        text: 'Supercalifragilistic',
        style: DisplayTitle.styleAt(base, size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, lessThanOrEqualTo(300));
    painter.dispose();
  });

  test('stops at the minimum size', () {
    final size = fitDisplaySize(
      'A title far too long for the space it is given here',
      base: base,
      width: 40,
      maxSize: 100,
      minSize: 24,
      maxLines: 1,
    );

    expect(size, 24);
  });
}
