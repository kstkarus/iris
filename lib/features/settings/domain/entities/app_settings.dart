enum AppThemePreference { system, light, dark }

enum AppLocalePreference { system, russian, english }

enum AnimeTitleLanguage { auto, russian, romaji, english }

enum EpisodeListLayout { auto, list, grid }

enum DefaultAudioLanguage { auto, japanese, russian, english }

enum DefaultSubtitleLanguage { auto, russian, english, off }

final class AppSettings {
  const AppSettings({
    this.themeMode = AppThemePreference.system,
    this.locale = AppLocalePreference.system,
    this.animeTitleLanguage = AnimeTitleLanguage.auto,
    this.episodeListLayout = EpisodeListLayout.auto,
    this.defaultAudioLanguage = DefaultAudioLanguage.auto,
    this.defaultSubtitleLanguage = DefaultSubtitleLanguage.auto,
  });

  final AppThemePreference themeMode;
  final AppLocalePreference locale;
  final AnimeTitleLanguage animeTitleLanguage;
  final EpisodeListLayout episodeListLayout;
  final DefaultAudioLanguage defaultAudioLanguage;
  final DefaultSubtitleLanguage defaultSubtitleLanguage;

  AppSettings copyWith({
    AppThemePreference? themeMode,
    AppLocalePreference? locale,
    AnimeTitleLanguage? animeTitleLanguage,
    EpisodeListLayout? episodeListLayout,
    DefaultAudioLanguage? defaultAudioLanguage,
    DefaultSubtitleLanguage? defaultSubtitleLanguage,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    locale: locale ?? this.locale,
    animeTitleLanguage: animeTitleLanguage ?? this.animeTitleLanguage,
    episodeListLayout: episodeListLayout ?? this.episodeListLayout,
    defaultAudioLanguage: defaultAudioLanguage ?? this.defaultAudioLanguage,
    defaultSubtitleLanguage:
        defaultSubtitleLanguage ?? this.defaultSubtitleLanguage,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.themeMode == themeMode &&
      other.locale == locale &&
      other.animeTitleLanguage == animeTitleLanguage &&
      other.episodeListLayout == episodeListLayout &&
      other.defaultAudioLanguage == defaultAudioLanguage &&
      other.defaultSubtitleLanguage == defaultSubtitleLanguage;

  @override
  int get hashCode => Object.hash(
    themeMode,
    locale,
    animeTitleLanguage,
    episodeListLayout,
    defaultAudioLanguage,
    defaultSubtitleLanguage,
  );
}
