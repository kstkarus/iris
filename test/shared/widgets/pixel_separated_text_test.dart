import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/pixel_separated_text.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('metadata stays readable to screen readers across input forms', (
    tester,
  ) async {
    for (final (child, label) in [
      (const PixelSeparatedText.parts(['TV', '', '2023']), 'TV, 2023'),
      (
        const PixelSeparatedText(
          '5 апр. 2009\u00A0г.',
          sansStyle: TextStyle(fontFamily: 'Medeo Sans'),
          monoStyle: TextStyle(fontFamily: 'Medeo Mono'),
        ),
        '5 апр. 2009\u00A0г.',
      ),
      (
        const PixelSeparatedText.spans([
          TextSpan(text: 'Downloading'),
          TextSpan(
            text: '42%',
            style: TextStyle(color: Colors.green),
          ),
        ]),
        'Downloading, 42%',
      ),
    ]) {
      await tester.pumpWidget(testApp(Scaffold(body: child)));
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
  });

  testWidgets('wraps segments onto clean lines without dangling separators', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: SizedBox(
            width: 140,
            child: PixelSeparatedText.parts([
              '38.1 GiB',
              '412 seeders',
              '18,204 downloads',
              'Mar 22, 2024',
            ], cleanLineWrap: true),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel(
        '38.1 GiB, 412 seeders, 18,204 downloads, Mar 22, 2024',
      ),
      findsOneWidget,
    );
    final first = tester.getTopLeft(
      find.textContaining('38.1 GiB', findRichText: true),
    );
    final third = tester.getTopLeft(
      find.textContaining('18,204 downloads', findRichText: true),
    );
    expect(third.dy, greaterThan(first.dy));
    expect(third.dx, equals(first.dx));
  });
}
