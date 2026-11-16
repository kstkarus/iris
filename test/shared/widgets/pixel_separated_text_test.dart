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
}
