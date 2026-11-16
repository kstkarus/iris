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
      text: TextSpan(text: text, style: DisplayTitle.styleAt(base, size!)),
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
        style: DisplayTitle.styleAt(base, size!),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    expect(painter.width, lessThanOrEqualTo(300));
    painter.dispose();
  });

  test('reports when even the minimum size cannot fit', () {
    final size = fitDisplaySize(
      'A title far too long for the space it is given here',
      base: base,
      width: 40,
      maxSize: 100,
      minSize: 24,
      maxLines: 1,
    );

    expect(size, isNull);
  });

  test('snaps to integer multiples of snapStep when requested', () {
    const step = 1000 / 38;
    final size = fitDisplaySize(
      'Iris',
      base: base,
      width: 2000,
      maxSize: 56,
      minSize: 20,
      maxLines: 1,
      snapStep: step,
    );

    expect(size, closeTo(2 * step, 0.0001));
  });

  test('picks nearest multiple of snapStep instead of strictly flooring', () {
    const step = (1000 / 38) / 2;
    final size = fitDisplaySize(
      'Iris',
      base: base,
      width: 2000,
      maxSize: 36,
      minSize: 20,
      maxLines: 1,
      snapStep: step,
    );

    expect(size, closeTo(3 * step, 0.0001));
  });

  test(
    'drops below preferredMinSize rather than returning off-grid when snapStep misses',
    () {
      const step = 1000 / 38;
      final twoStepPainter = TextPainter(
        text: TextSpan(
          text: 'Sousou no',
          style: DisplayTitle.styleAt(base, 2 * step),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final width = twoStepPainter.width - 2;
      twoStepPainter.dispose();

      final size = fitDisplaySize(
        'Sousou no',
        base: base,
        width: width,
        maxSize: 40,
        minSize: 16,
        preferredMinSize: 30,
        maxLines: 1,
        snapStep: step,
      );

      expect(size, lessThan(30));
      expect(size, greaterThanOrEqualTo(16));
    },
  );

  testWidgets(
    'uses the fallback when the primary title cannot fit above its threshold',
    (tester) async {
      Widget buildFor(String title, {required double minSize}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 140,
            child: DisplayTitle(
              title,
              fontFamily: 'Medeo Pixel Grid',
              maxSize: 40,
              minSize: minSize,
              preferredMinSize: 24,
              maxLines: 2,
              snapStep: 1000 / 38,
              fallbackStyleAt: (base, size) => base.copyWith(
                fontFamily: 'Medeo Mono',
                fontSize: size,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );

      for (final minSize in [16.0, 24.0]) {
        await tester.pumpWidget(buildFor('Iris', minSize: minSize));
        final shortText = tester.widget<Text>(find.text('Iris'));
        expect(shortText.style?.fontFamily, 'Medeo Pixel Grid');

        await tester.pumpWidget(
          buildFor('Tensei shitara Slime Datta Ken', minSize: minSize),
        );
        final longText = tester.widget<Text>(
          find.text('Tensei shitara Slime Datta Ken'),
        );
        expect(longText.style?.fontFamily, 'Medeo Mono');
      }
    },
  );

  test('falls below preferredMinSize toward minSize when space requires', () {
    final fitsAt24 = TextPainter(
      text: TextSpan(
        text: 'UnbreakableTitleWord',
        style: DisplayTitle.styleAt(base, 26),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = fitsAt24.width + 2;
    fitsAt24.dispose();

    final size = fitDisplaySize(
      'UnbreakableTitleWord',
      base: base,
      width: width,
      maxSize: 40,
      minSize: 20,
      preferredMinSize: 32,
      maxLines: 1,
      snapStep: 1000 / 38,
    );

    expect(size, lessThan(32));
    expect(size, greaterThanOrEqualTo(20));
  });

  testWidgets('ignores system text scaling when respectTextScale is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: DisplayTitle(
                'Iris',
                maxSize: 30,
                minSize: 20,
                respectTextScale: false,
              ),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Iris'));
    expect(text.textScaler, TextScaler.noScaling);
  });
}
