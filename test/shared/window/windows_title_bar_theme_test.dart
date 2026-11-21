import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/app.dart';
import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_state.dart';
import 'package:iris/features/player/presentation/pages/player_page.dart';
import 'package:iris/shared/window/windows_title_bar_theme.dart';

import '../../features/player/player_test_doubles.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('iris/window');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('sends ARGB frame colors only when a frame color changes', (
    tester,
  ) async {
    final theme = WindowsTitleBarTheme();
    const caption = Color(0xff123456);
    const text = Color(0xfffedcba);
    const border = Color(0xffabcdef);
    final scheme = buildAppTheme().colorScheme.copyWith(
      surface: caption,
      onSurface: text,
      outlineVariant: border,
    );
    theme.setAppTheme(scheme);
    theme.setAppTheme(scheme.copyWith(primary: Colors.red));
    await tester.pump();

    expect(calls.single.method, 'setTitleBarTheme');
    expect(calls.single.arguments, {
      'dark': false,
      'captionColor': 0xff123456,
      'textColor': 0xfffedcba,
      'borderColor': 0xffabcdef,
    });
    theme.setAppTheme(scheme.copyWith(outlineVariant: Colors.blue));
    await tester.pump();
    expect(calls.last.arguments['borderColor'], Colors.blue.toARGB32());
    expect(calls, hasLength(2));
  }, variant: const TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('app and system appearance follow Settings and player pop', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
        GoRoute(
          path: '/player',
          pageBuilder: (_, _) => NoTransitionPage(
            child: BlocProvider<PlayerCubit>(
              create: (_) => FakePlayerCubit(
                const PlayerPreparing(),
                source: fmaPlayerSource,
              ),
              child: const PlayerPage(
                viewportFactory: FakePlayerViewportFactory(),
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final dispatcher = tester.binding.platformDispatcher;
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
    addTearDown(dispatcher.clearPlatformBrightnessTestValue);
    final downloads = MockDownloadsRepository();

    Future<void> showApp(ThemeMode mode) async {
      await tester.pumpWidget(
        IrisApp(
          router: router,
          downloadsRepository: downloads,
          themeMode: mode,
        ),
      );
      await tester.pump();
    }

    void expectFrame(bool dark) {
      expect(calls.last.arguments['dark'], dark);
      expect(
        calls.last.arguments['captionColor'],
        dark ? 0xff141414 : 0xfff1edeb,
      );
    }

    dispatcher.platformBrightnessTestValue = Brightness.dark;
    await showApp(ThemeMode.system);
    expectFrame(true);
    await showApp(ThemeMode.light);
    expectFrame(false);
    await showApp(ThemeMode.dark);
    expectFrame(true);
    dispatcher.platformBrightnessTestValue = Brightness.light;
    await showApp(ThemeMode.system);
    expectFrame(false);
    dispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    expectFrame(true);

    await showApp(ThemeMode.light);
    router.push<void>('/player');
    await tester.pump();
    expect(find.byType(PlayerPage), findsOneWidget);
    expectFrame(true);

    final duringPlayer = calls.length;
    await showApp(ThemeMode.dark);
    await showApp(ThemeMode.light);
    expect(calls, hasLength(duringPlayer));

    router.pop();
    await tester.pump();
    expect(find.byType(PlayerPage), findsNothing);
    expectFrame(false);
  }, variant: const TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('does not use the native window channel on Android', (
    tester,
  ) async {
    final theme = WindowsTitleBarTheme();
    final player = Object();
    theme.setAppTheme(buildAppTheme().colorScheme);
    theme.setPlayerTheme(
      player,
      buildAppTheme(brightness: Brightness.dark).colorScheme,
    );
    theme.clearPlayerTheme(player);
    await tester.pump();
    expect(calls, isEmpty);
  }, variant: const TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('restores the app after the last player closes', (tester) async {
    final theme = WindowsTitleBarTheme();
    final light = buildAppTheme().colorScheme;
    final dark = buildAppTheme(brightness: Brightness.dark).colorScheme;
    final first = Object();
    final second = Object();
    theme.setAppTheme(light);
    theme.setPlayerTheme(first, dark);
    theme.setPlayerTheme(second, dark);
    theme.clearPlayerTheme(first);
    await tester.pump();
    expect(calls.map((call) => call.arguments['dark']), [false, true]);

    theme.clearPlayerTheme(second);
    await tester.pump();
    expect(calls.map((call) => call.arguments['dark']), [false, true, false]);
  }, variant: const TargetPlatformVariant({TargetPlatform.windows}));
}
