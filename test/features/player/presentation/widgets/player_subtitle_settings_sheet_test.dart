import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_settings_sheet.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('renders subtitle settings controls', (tester) async {
    await tester.pumpWidget(_wrap(child: const PlayerSubtitleSettingsSheet()));

    expect(find.text('Subtitle Appearance'), findsOneWidget);
    expect(find.text('Show subtitles'), findsOneWidget);
    expect(find.text('Improved ASS/SSA rendering'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('0.85x'), findsOneWidget);
    expect(find.text('1.30x'), findsOneWidget);
  });

  testWidgets('updates cubit when selecting presets', (tester) async {
    final repository = _FakeSubtitlePreferencesRepository(
      const SubtitlePreferences.defaults(),
    );
    final cubit = PlayerSubtitlePreferencesCubit(repository: repository);

    await tester.pumpWidget(
      _wrap(cubit: cubit, child: const PlayerSubtitleSettingsSheet()),
    );

    await tester.tap(find.text('1.15x'));
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

      expect(find.text('Subtitle Appearance'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _wrap({PlayerSubtitlePreferencesCubit? cubit, required Widget child}) {
  final value =
      cubit ??
      PlayerSubtitlePreferencesCubit(
        repository: _FakeSubtitlePreferencesRepository(
          const SubtitlePreferences.defaults(),
        ),
      );

  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<PlayerSubtitlePreferencesCubit>.value(
      value: value,
      child: Scaffold(body: child),
    ),
  );
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
