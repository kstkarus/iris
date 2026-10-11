import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/widgets/player_view.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';

import '../../../../helpers/test_app.dart';
import '../../player_test_doubles.dart';

void main() {
  testWidgets('shows the preparation state', (tester) async {
    final cubit = FakePlayerCubit(
      const PlayerPreparing(),
      source: fmaPlayerSource,
    );

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(find.text('Preparing video'), findsOneWidget);
    // Nothing reports progress before the player opens: no zero figures.
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('/s'), findsNothing);
  });

  testWidgets('shows player viewport when playback is ready', (tester) async {
    final cubit = FakePlayerCubit(
      const PlayerReady(
        PlayerSession(
          sessionId: '42',
          streamUrl: 'http://127.0.0.1:8080/stream/2',
        ),
      ),
      source: fmaPlayerSource,
    );

    await tester.pumpWidget(
      _wrap(cubit: cubit, factory: const FakePlayerViewportFactory()),
    );

    expect(find.byKey(const Key('player_video_surface')), findsOneWidget);
  });

  testWidgets('keeps the player on screen while the next file starts', (
    tester,
  ) async {
    final cubit = FakePlayerCubit(
      const PlayerPreparing(keepsPlayer: true),
      source: fmaPlayerSource,
    );

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(find.byKey(const Key('player_video_surface')), findsOneWidget);
    expect(find.text('Preparing video'), findsNothing);
  });

  testWidgets('shows retry action on generic failure', (tester) async {
    final cubit = FakePlayerCubit(
      const PlayerFailure(),
      source: fmaPlayerSource,
    );

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(find.text('Unable to start playback.'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    await tester.tap(find.text('Try Again'));
    expect(cubit.loadCalls, 1);
  });

  for (final state in const [PlayerPreparing(), PlayerFailure()]) {
    testWidgets('keeps a way back while ${state.runtimeType} has no player', (
      tester,
    ) async {
      var backs = 0;
      final cubit = FakePlayerCubit(state, source: fmaPlayerSource);

      await tester.pumpWidget(_wrap(cubit: cubit, onBack: () => backs++));
      await tester.tap(find.byKey(const Key('player_back_button')));

      expect(backs, 1);
    });
  }

  testWidgets('passes the input on to the viewport', (tester) async {
    final cubit = FakePlayerCubit(
      const PlayerReady(
        PlayerSession(
          sessionId: '42',
          streamUrl: 'http://127.0.0.1:8080/stream/2',
        ),
      ),
      source: fmaPlayerSource,
    );

    await tester.pumpWidget(_wrap(cubit: cubit, input: PlayerInputMode.touch));

    expect(find.text('input: touch'), findsOneWidget);
  });
}

Widget _wrap({
  required FakePlayerCubit cubit,
  PlayerViewportFactory factory = const FakePlayerViewportFactory(),
  PlayerInputMode input = PlayerInputMode.pointer,
  VoidCallback? onBack,
}) {
  return testApp(
    BlocProvider<PlayerCubit>.value(
      value: cubit,
      child: Scaffold(
        body: PlayerView(
          viewportFactory: factory,
          input: input,
          chrome: PlayerChrome(title: 'Episode 2', onBack: onBack ?? () {}),
        ),
      ),
    ),
  );
}
