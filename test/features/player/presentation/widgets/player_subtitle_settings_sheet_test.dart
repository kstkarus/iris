import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/widgets/player_choice_row.dart';
import 'package:iris/features/player/presentation/widgets/player_overlay_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_settings_sheet.dart';
import 'package:iris/shared/widgets/segmented_choice.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../player_test_doubles.dart';

const _textTracks = Tracks(
  subtitle: [SubtitleTrack('1', 'Russian', 'ru', codec: 'ass')],
);

void main() {
  tearDown(() => playerDetailedStatsEnabled.value = false);

  testWidgets('omits subtitle settings without a real subtitle track', (
    tester,
  ) async {
    final cubit = PlayerSubtitlePreferencesCubit(
      repository: MemorySubtitlePreferencesRepository(
        const SubtitlePreferences.defaults().copyWith(
          textColor: SubtitleTextColorPreset.yellow,
        ),
      ),
    );
    await cubit.loadPreferences();
    await tester.pumpWidget(
      _wrap(
        cubit: cubit,
        child: const PlayerSubtitleSettingsSheet(tracks: Tracks()),
      ),
    );

    expect(find.text('SUBTITLE APPEARANCE'), findsNothing);
    expect(find.text('Decoder: Auto'), findsOneWidget);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ASS'), findsNothing);
    expect(find.text('Auto (recommended)').hitTestable(), findsOneWidget);
    expect(
      find.byKey(const Key('player_detailed_stats_switch')).hitTestable(),
      findsOneWidget,
    );
    expect(cubit.state.textColor, SubtitleTextColorPreset.yellow);
  });

  testWidgets('keeps text styling with subtitles Off and hides it for PGS', (
    tester,
  ) async {
    const tracks = Tracks(
      subtitle: [
        SubtitleTrack('1', 'Russian', 'ru', codec: 'ass'),
        SubtitleTrack('2', 'English', 'en', codec: 'hdmv_pgs_subtitle'),
      ],
    );
    final cubit = PlayerSubtitlePreferencesCubit(
      repository: MemorySubtitlePreferencesRepository(),
    );
    for (final (selected, showAppearance) in [
      (SubtitleTrack.no(), true),
      (const SubtitleTrack('1', 'Russian', 'ru'), true),
      (const SubtitleTrack('2', 'English', 'en'), false),
    ]) {
      await tester.pumpWidget(
        _wrap(
          cubit: cubit,
          child: PlayerSubtitleSettingsSheet(
            tracks: tracks,
            selectedSubtitleTrack: selected,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('SUBTITLE APPEARANCE'),
        showAppearance ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('changes playback speed when it is offered', (tester) async {
    final rate = ValueNotifier<double>(1);
    addTearDown(rate.dispose);
    await tester.pumpWidget(
      _wrap(
        child: PlayerSubtitleSettingsSheet(
          tracks: _textTracks,
          speed: PlayerSpeedSetting(
            rate: rate,
            onSelected: (value) => rate.value = value,
          ),
        ),
      ),
    );

    expect(find.text('Playback speed'), findsOneWidget);
    for (final label in ['0.5×', '0.75×', '1×', '1.25×', '1.5×', '2×']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    await tester.tap(find.text('1.5×'));
    await tester.pump();
    expect(rate.value, 1.5);
    expect(
      tester
          .widget<SegmentedChoice<double>>(
            find.byKey(const Key('player_speed_choice')),
          )
          .selected,
      1.5,
    );
  });

  testWidgets('leaves the speed out when it is not offered', (tester) async {
    await tester.pumpWidget(
      _wrap(child: const PlayerSubtitleSettingsSheet(tracks: _textTracks)),
    );

    expect(find.text('Playback speed'), findsNothing);
  });

  testWidgets('updates cubit when selecting presets', (tester) async {
    final repository = MemorySubtitlePreferencesRepository(
      const SubtitlePreferences.defaults(),
    );
    final cubit = PlayerSubtitlePreferencesCubit(repository: repository);

    await tester.pumpWidget(
      _wrap(
        cubit: cubit,
        child: const PlayerSubtitleSettingsSheet(tracks: _textTracks),
      ),
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
    await tester.pumpWidget(
      _wrap(child: const PlayerSubtitleSettingsSheet(tracks: _textTracks)),
    );

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
      repository: MemorySubtitlePreferencesRepository(),
    );
    const warning =
        "A custom colour, background or position replaces the release's "
        'styling: styled signs become plain text.';

    await tester.pumpWidget(
      _wrap(
        cubit: cubit,
        child: const PlayerSubtitleSettingsSheet(tracks: _textTracks),
      ),
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reset'))
          .onPressed,
      isNull,
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
    final repository = MemorySubtitlePreferencesRepository(
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
      _wrap(
        cubit: cubit,
        child: const PlayerSubtitleSettingsSheet(tracks: _textTracks),
      ),
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
    final decodingRepository = MemoryDecodingPreferencesRepository();
    final decodingCubit = PlayerDecodingPreferencesCubit(
      repository: decodingRepository,
    );

    await tester.pumpWidget(
      _wrap(
        decodingCubit: decodingCubit,
        child: const PlayerSubtitleSettingsSheet(tracks: _textTracks),
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
    setTestWindowSize(tester, TestWindowSizes.phone);

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

  for (final size in const [Size(1280, 800), Size(400, 800)]) {
    testWidgets(
      'settings change from a modal route at ${size.width.toInt()} dp',
      (tester) async {
        setTestWindowSize(tester, size);
        final cubit = PlayerSubtitlePreferencesCubit(
          repository: MemorySubtitlePreferencesRepository(),
        );
        addTearDown(cubit.close);
        await tester.pumpWidget(
          _wrap(cubit: cubit, child: const _OpenSettingsButton()),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.bySemanticsLabel('Larger'));
        await tester.tap(find.bySemanticsLabel('Larger'));
        await tester.pump();
        expect(cubit.state.textScale, SubtitleTextScalePreset.large);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('shows MediaCodec decoder options on Android', (tester) async {
    await tester.pumpWidget(
      _wrap(child: const PlayerSubtitleSettingsSheet(tracks: _textTracks)),
    );

    expect(find.text('Auto (recommended)'), findsOneWidget);
    expect(find.text('MediaCodec'), findsOneWidget);
    expect(find.text('MediaCodec (copy-back)'), findsOneWidget);
    expect(find.text('Software only'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('hides MediaCodec decoder options on desktop', (tester) async {
    await tester.pumpWidget(
      _wrap(child: const PlayerSubtitleSettingsSheet(tracks: _textTracks)),
    );

    expect(find.text('Auto (recommended)'), findsOneWidget);
    expect(find.text('Software only'), findsOneWidget);
    expect(find.text('MediaCodec'), findsNothing);
    expect(find.text('MediaCodec (copy-back)'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'shows auto decoder as selected on desktop for a stored MediaCodec preset',
    (tester) async {
      final decodingCubit = PlayerDecodingPreferencesCubit(
        repository: MemoryDecodingPreferencesRepository(
          const PlayerDecodingPreferences(
            hwdecMode: PlayerHwdecModePreset.mediacodecCopy,
          ),
        ),
      );
      await decodingCubit.loadPreferences();

      await tester.pumpWidget(
        _wrap(
          decodingCubit: decodingCubit,
          child: const PlayerSubtitleSettingsSheet(tracks: _textTracks),
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
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}

class _OpenSettingsButton extends StatelessWidget {
  const _OpenSettingsButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: () => showPlayerSubtitleSettingsSheet(
          context,
          tracks: const AlwaysStoppedAnimation(_textTracks),
          selectedTrack: const AlwaysStoppedAnimation(Track()),
        ),
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
        repository: MemorySubtitlePreferencesRepository(),
      );
  final effectiveDecodingCubit =
      decodingCubit ??
      PlayerDecodingPreferencesCubit(
        repository: MemoryDecodingPreferencesRepository(),
      );

  return testApp(
    MultiBlocProvider(
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
