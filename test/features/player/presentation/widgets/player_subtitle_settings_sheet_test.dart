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
import 'package:iris/features/player/presentation/widgets/player_subtitle_settings_sheet.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('renders subtitle settings controls', (tester) async {
    await tester.pumpWidget(_wrap(child: const PlayerSubtitleSettingsSheet()));

    expect(find.text('Player Settings'), findsOneWidget);
    expect(find.text('Subtitle Appearance'), findsOneWidget);
    expect(find.text('Decoder'), findsOneWidget);
    expect(find.text('Auto (recommended)'), findsOneWidget);
    expect(find.text('Software only'), findsOneWidget);
    expect(find.text('Show subtitles'), findsOneWidget);
    expect(find.text('Improved ASS/SSA rendering'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('0.85x'), findsOneWidget);
    expect(find.text('1.30x'), findsOneWidget);
  });

  testWidgets('updates decoding cubit when selecting decoder mode', (
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

    await tester.tap(find.text('Software only'));
    await tester.pump();

    expect(decodingCubit.state.hwdecMode, PlayerHwdecModePreset.softwareOnly);
    expect(
      decodingRepository.state.hwdecMode,
      PlayerHwdecModePreset.softwareOnly,
    );
  });

  testWidgets('updates cubit when selecting presets', (tester) async {
    final repository = _FakeSubtitlePreferencesRepository(
      const SubtitlePreferences.defaults(),
    );
    final cubit = PlayerSubtitlePreferencesCubit(repository: repository);

    await tester.pumpWidget(
      _wrap(cubit: cubit, child: const PlayerSubtitleSettingsSheet()),
    );

    await tester.ensureVisible(find.text('1.15x'));
    await tester.tap(find.text('1.15x'));
    await tester.pump();
    await tester.ensureVisible(find.text('Yellow'));
    await tester.tap(find.text('Yellow'));
    await tester.pump();
    await tester.ensureVisible(find.text('Higher'));
    await tester.tap(find.text('Higher'));
    await tester.pumpAndSettle();

    expect(cubit.state.textScale, SubtitleTextScalePreset.large);
    expect(cubit.state.textColor, SubtitleTextColorPreset.yellow);
    expect(cubit.state.verticalPosition, SubtitleVerticalPositionPreset.high);
  });

  testWidgets('resets to defaults', (tester) async {
    final repository = _FakeSubtitlePreferencesRepository(
      const SubtitlePreferences(
        visible: false,
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

    await tester.ensureVisible(find.text('Reset'));
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(cubit.state, const SubtitlePreferences.defaults());
  });

  testWidgets(
    'opens subtitle settings from a modal route without losing cubit access',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showPlayerSubtitleSettingsSheet(context),
                    child: const Text('Open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Player Settings'), findsOneWidget);
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
      expect(find.text('MediaCodec (zero-copy)'), findsOneWidget);
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
      expect(find.text('MediaCodec (zero-copy)'), findsNothing);
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

        final autoChip = tester.widget<ChoiceChip>(
          find.ancestor(
            of: find.text('Auto (recommended)'),
            matching: find.byType(ChoiceChip),
          ),
        );
        expect(autoChip.selected, isTrue);
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
    expect(find.text('Player Settings'), findsOneWidget);
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
    expect(find.text('Player Settings'), findsOneWidget);
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
