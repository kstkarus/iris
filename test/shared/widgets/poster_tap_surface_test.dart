import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/widgets/poster_tap_surface.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('tracks hover with click cursor and no rectangular hover slab', (
    tester,
  ) async {
    var tapped = false;
    var lastHovered = false;

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              height: 180,
              child: PosterTapSurface(
                onTap: () => tapped = true,
                builder: (context, hovered, focused) {
                  lastHovered = hovered;
                  return PosterHoverFrame(
                    hovered: hovered,
                    focused: focused,
                    poster: const ColoredBox(color: Colors.black),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.mouseCursor, SystemMouseCursors.click);
    expect(inkWell.hoverColor, Colors.transparent);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    await mouse.moveTo(tester.getCenter(find.byType(PosterTapSurface)));
    await tester.pumpAndSettle();
    expect(lastHovered, isTrue);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(lastHovered, isFalse);

    await tester.tap(find.byType(PosterTapSurface));
    expect(tapped, isTrue);
  });

  testWidgets('border highlights immediately under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 180,
                child: PosterHoverFrame(
                  hovered: true,
                  focused: false,
                  poster: ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final frame = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(frame.duration, Duration.zero);
    expect(find.byType(AnimatedScale), findsNothing);
  });
}
