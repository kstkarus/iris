import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/repositories/player_decoding_preferences_repository.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/widgets/player_choice_row.dart';
import 'package:iris/features/player/presentation/widgets/player_overlay_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_settings_sheet.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  tearDown(() => playerDetailedStatsEnabled.value = false);

  testWidgets('puts the look of subtitles first and folds the rest', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(child: const PlayerSubtitleSettingsSheet()));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('SUBTITLE APPEARANCE'), findsOneWidget);
    expect(find.text('Show subtitles'), findsNothing);
    expect(find.bySemanticsLabel('Larger'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Decoder: Auto · ASS rendering: on'), findsOneWidget);
    // Folded: there, but out of reach until Advanced opens.
    expect(find.text('Software only').hitTestable(), findsNothing);
    // Nothing to reset at the defaults.
    final reset = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Reset'),
    );
    expect(reset.onPressed, isNull);
  });

  testWidgets('updates cubit when selecting presets', (tester) async {
    final repository = _FakeSubtitlePreferencesRepository(
      const SubtitlePreferences.defaults(),
    );
    final cubit = PlayerSubtitlePreferencesCubit(repository: repository);

    await tester.pumpWidget(
      _wrap(cubit: cubit, child: const PlayerSubtitleSettingsSheet()),
    );

    await tester.tap(find.bySemanticsLabel('Larger'));
    await tester.pump();
    await tester.tap(find.text('Yellow'));
    await tester.pump();
    await tester.ensureVisible(find.text('Higher'));
    await tester.tap(find.text('Higher'));
    await tester.pumpAndSettle();

    expect(cubit.state.textScale, SubtitleTextScalePreset.large);
    expect(cubit.state.textColor, SubtitleTextColorPreset.yellow);
    expect(cubit.state.verticalPosition, SubtitleVerticalPositionPreset.high);
  });

  testWidgets('a choice of one tells assistive technology what is chosen', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(child: const PlayerSubtitleSettingsSheet()));

    Matcher cell({required bool selected}) => isSemantics(
      label: selected ? 'Normal' : 'Larger',
      isButton: true,
      hasSelectedState: true,
      isSelected: selected,
      isInMutuallyExclusiveGroup: true,
      hasTapAction: true,
      isFocusable: true,
      hasFocusAction: true,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Normal')),
      cell(selected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Larger')),
      cell(selected: false),
    );
    semantics.dispose();
  });

  testWidgets('warns that a custom look replaces the release styling', (
    tester,
  ) async {
    final cubit = PlayerSubtitlePreferencesCubit(
      repository: _FakeSubtitlePreferencesRepository(
        const SubtitlePreferences.defaults(),
      ),
    );
    const warning =
        "A custom colour, background or position replaces the release's "
        'styling: styled signs become plain text.';

    await tester.pumpWidget(
      _wrap(cubit: cubit, child: const PlayerSubtitleSettingsSheet()),
    );
    expect(find.text(warning).hitTestable(), findsNothing);

    await cubit.setTextColor(SubtitleTextColorPreset.yellow);
    await tester.pumpAndSettle();
    expect(find.text(warning).hitTestable(), findsOneWidget);

    // Without the release renderer there is no styling to lose.
    await cubit.setLibassEnabled(false);
    await tester.pumpAndSettle();
    expect(find.text(warning).hitTestable(), findsNothing);
  });

  testWidgets('resets the look and keeps the renderer', (tester) async {
    final repository = _FakeSubtitlePreferencesRepository(
      const SubtitlePreferences(
        libassEnabled: false,
        textScale: SubtitleTextScalePreset.compact,
        textColor: SubtitleTextColorPreset.cyan,
        backgroundStyle: SubtitleBackgroundStylePreset.none,
        verticalPosition: SubtitleVerticalPositionPreset.high,
      ),
    );
    final cubit = PlayerSubtitlePreferencesCubit(repository: repository);
    await cubit.loadPreferences();

    await tester.pumpWidget(
      _wrap(cubit: cubit, child: const PlayerSubtitleSettingsSheet()),
    );

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(
      cubit.state,
      const SubtitlePreferences.defaults().copyWith(libassEnabled: false),
    );
  });

  testWidgets('Advanced unfolds the decoder, renderer and technical details', (
    tester,
  ) async {
    final decodingRepository = _FakePlayerDecodingPreferencesRepository(
      const PlayerDecodingPreferences.defaults(),
    );
    final decodingCubit = PlayerDecodingPreferencesCubit(
      repository: decodingRepository,
    );

    await tester.pumpWidget(
      _wrap(
        decodingCubit: decodingCubit,
        child: const PlayerSubtitleSettingsSheet(),
      ),
    );

    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(
      find.text('Decoder: Auto · ASS rendering: on').hitTestable(),
      findsNothing,
    );

    await tester.tap(find.text('Software only'));
    await tester.pump();
    expect(decodingCubit.state.hwdecMode, PlayerHwdecModePreset.softwareOnly);
    expect(
      decodingRepository.state.hwdecMode,
      PlayerHwdecModePreset.softwareOnly,
    );

    await tester.ensureVisible(
      find.byKey(const Key('player_detailed_stats_switch')),
    );
    await tester.tap(find.byKey(const Key('player_detailed_stats_switch')));
    await tester.pump();
    expect(playerDetailedStatsEnabled.value, isTrue);

    await tester.ensureVisible(find.text('Advanced'));
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(
      find.text('Decoder: Software only · ASS rendering: on'),
      findsOneWidget,
    );
    expect(find.text('Software only').hitTestable(), findsNothing);
  });

  testWidgets('scrolls Advanced into view once it has unfolded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(child: const _OpenSettingsButton()));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(PlayerSubtitleSettingsSheet),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(position.pixels, 0);

    await tester.tap(find.text('Advanced'));
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(
      find.byKey(const Key('player_detailed_stats_switch')).hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets(
    'opens subtitle settings from a modal route without losing cubit access',
    (tester) async {
      await tester.pumpWidget(_wrap(child: const _OpenSettingsButton()));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows MediaCodec decoder options on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        _wrap(child: const PlayerSubtitleSettingsSheet()),
      );

      expect(find.text('Auto (recommended)'), findsOneWidget);
      expect(find.text('MediaCodec'), findsOneWidget);
      expect(find.text('MediaCodec (copy-back)'), findsOneWidget);
      expect(find.text('Software only'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('hides MediaCodec decoder options on desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(
        _wrap(child: const PlayerSubtitleSettingsSheet()),
      );

      expect(find.text('Auto (recommended)'), findsOneWidget);
      expect(find.text('Software only'), findsOneWidget);
      expect(find.text('MediaCodec'), findsNothing);
      expect(find.text('MediaCodec (copy-back)'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'shows auto decoder as selected on desktop for a stored MediaCodec preset',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final decodingCubit = PlayerDecodingPreferencesCubit(
          repository: _FakePlayerDecodingPreferencesRepository(
            const PlayerDecodingPreferences(
              hwdecMode: PlayerHwdecModePreset.mediacodecCopy,
            ),
          ),
        );
        await decodingCubit.loadPreferences();

        await tester.pumpWidget(
          _wrap(
            decodingCubit: decodingCubit,
            child: const PlayerSubtitleSettingsSheet(),
          ),
        );

        final autoRow = tester.widget<PlayerChoiceRow>(
          find.ancestor(
            of: find.text('Auto (recommended)'),
            matching: find.byType(PlayerChoiceRow),
          ),
        );
        expect(autoRow.selected, isTrue);
        expect(find.text('Decoder: Auto · ASS rendering: on'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('opens settings as a dialog on wide windows', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(child: const _OpenSettingsButton()));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('player_adaptive_sheet_dialog')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    final dialogContentSize = tester.getSize(
      find.descendant(
        of: find.byKey(const Key('player_adaptive_sheet_dialog')),
        matching: find.byType(PlayerSubtitleSettingsSheet),
      ),
    );
    expect(dialogContentSize.width, lessThanOrEqualTo(560));
  });

  testWidgets('opens settings as a bottom sheet on compact phones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(child: const _OpenSettingsButton()));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const Key('player_adaptive_sheet_dialog')), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaves the video lightly dimmed behind the settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(child: const _OpenSettingsButton()));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
    expect(barrier.color!.a, lessThan(0.3));
  });
}

class _OpenSettingsButton extends StatelessWidget {
  const _OpenSettingsButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: () => showPlayerSubtitleSettingsSheet(context),
        child: const Text('Open'),
      ),
    );
  }
}

Widget _wrap({
  PlayerSubtitlePreferencesCubit? cubit,
  PlayerDecodingPreferencesCubit? decodingCubit,
  required Widget child,
}) {
  final subtitleCubit =
      cubit ??
      PlayerSubtitlePreferencesCubit(
        repository: _FakeSubtitlePreferencesRepository(
          const SubtitlePreferences.defaults(),
        ),
      );
  final effectiveDecodingCubit =
      decodingCubit ??
      PlayerDecodingPreferencesCubit(
        repository: _FakePlayerDecodingPreferencesRepository(
          const PlayerDecodingPreferences.defaults(),
        ),
      );

  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<PlayerSubtitlePreferencesCubit>.value(
          value: subtitleCubit,
        ),
        BlocProvider<PlayerDecodingPreferencesCubit>.value(
          value: effectiveDecodingCubit,
        ),
      ],
      child: Scaffold(body: child),
    ),
  );
}

class _FakePlayerDecodingPreferencesRepository
    implements PlayerDecodingPreferencesRepository {
  _FakePlayerDecodingPreferencesRepository(this.state);

  PlayerDecodingPreferences state;

  @override
  Future<PlayerDecodingPreferences> loadPreferences() async => state;

  @override
  Future<void> savePreferences(PlayerDecodingPreferences preferences) async {
    state = preferences;
  }
}

class _FakeSubtitlePreferencesRepository
    implements SubtitlePreferencesRepository {
  _FakeSubtitlePreferencesRepository(this.state);

  SubtitlePreferences state;

  @override
  Future<SubtitlePreferences> loadPreferences() async => state;

  @override
  Future<void> savePreferences(SubtitlePreferences preferences) async {
    state = preferences;
  }
}
