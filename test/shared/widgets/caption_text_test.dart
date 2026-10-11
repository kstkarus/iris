import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/caption_text.dart';

void main() {
  testWidgets('a caption is upper-case, muted and tabular when asked', (
    tester,
  ) async {
    final theme = ThemeData();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Column(
          children: [
            CaptionText('ep 3', tabular: true),
            CaptionText('now', color: Colors.red),
          ],
        ),
      ),
    );

    final muted = tester.widget<Text>(find.text('EP 3')).style!;
    expect(muted.color, theme.colorScheme.onSurfaceVariant);
    expect(muted.fontFeatures, const [FontFeature.tabularFigures()]);

    final accent = tester.widget<Text>(find.text('NOW')).style!;
    expect(accent.color, Colors.red);
    expect(accent.fontFeatures, theme.textTheme.labelSmall?.fontFeatures);
  });
}
