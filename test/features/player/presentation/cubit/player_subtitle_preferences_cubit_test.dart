import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/domain/repositories/subtitle_preferences_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';

void main() {
  test('loads saved preferences from repository', () async {
    final repository = _FakeSubtitlePreferencesRepository(
      const SubtitlePreferences(
        visible: false,
        libassEnabled: false,
        textScale: SubtitleTextScalePreset.large,
        textColor: SubtitleTextColorPreset.yellow,
        backgroundStyle: SubtitleBackgroundStylePreset.solid,
        verticalPosition: SubtitleVerticalPositionPreset.high,
      ),
    );
    final cubit = PlayerSubtitlePreferencesCubit(repository: repository);

    await cubit.loadPreferences();

    expect(cubit.state.visible, isFalse);
    expect(cubit.state.libassEnabled, isFalse);
    expect(cubit.state.textScale, SubtitleTextScalePreset.large);
    expect(cubit.state.textColor, SubtitleTextColorPreset.yellow);
    expect(cubit.state.backgroundStyle, SubtitleBackgroundStylePreset.solid);
    expect(cubit.state.verticalPosition, SubtitleVerticalPositionPreset.high);
  });

  test('persists updates immediately', () async {
    final repository = _FakeSubtitlePreferencesRepository(
      const SubtitlePreferences.defaults(),
    );
    final cubit = PlayerSubtitlePreferencesCubit(repository: repository);

    await cubit.setTextScale(SubtitleTextScalePreset.compact);
    await cubit.setTextColor(SubtitleTextColorPreset.cyan);

    expect(repository.savedStates, hasLength(2));
    expect(cubit.state.textScale, SubtitleTextScalePreset.compact);
    expect(cubit.state.textColor, SubtitleTextColorPreset.cyan);
  });

  test('resets preferences back to defaults', () async {
    final repository = _FakeSubtitlePreferencesRepository(
      const SubtitlePreferences(
        visible: false,
        libassEnabled: false,
        textScale: SubtitleTextScalePreset.large,
        textColor: SubtitleTextColorPreset.yellow,
        backgroundStyle: SubtitleBackgroundStylePreset.none,
        verticalPosition: SubtitleVerticalPositionPreset.high,
      ),
    );
    final cubit = PlayerSubtitlePreferencesCubit(repository: repository);

    await cubit.loadPreferences();
    await cubit.reset();

    expect(cubit.state, const SubtitlePreferences.defaults());
    expect(repository.savedStates.last, const SubtitlePreferences.defaults());
  });
}

class _FakeSubtitlePreferencesRepository
    implements SubtitlePreferencesRepository {
  _FakeSubtitlePreferencesRepository(this.loadedState);

  SubtitlePreferences loadedState;
  final List<SubtitlePreferences> savedStates = [];

  @override
  Future<SubtitlePreferences> loadPreferences() async {
    return loadedState;
  }

  @override
  Future<void> savePreferences(SubtitlePreferences preferences) async {
    savedStates.add(preferences);
    loadedState = preferences;
  }
}
