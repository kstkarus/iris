import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Iris'**
  String get appName;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonRetry;

  /// No description provided for @animeKindTv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get animeKindTv;

  /// No description provided for @animeKindMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get animeKindMovie;

  /// No description provided for @animeKindOva.
  ///
  /// In en, this message translates to:
  /// **'OVA'**
  String get animeKindOva;

  /// No description provided for @animeKindOna.
  ///
  /// In en, this message translates to:
  /// **'ONA'**
  String get animeKindOna;

  /// No description provided for @animeStatusReleased.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get animeStatusReleased;

  /// No description provided for @animeStatusOngoing.
  ///
  /// In en, this message translates to:
  /// **'Ongoing'**
  String get animeStatusOngoing;

  /// No description provided for @animeStatusAnnounced.
  ///
  /// In en, this message translates to:
  /// **'Announced'**
  String get animeStatusAnnounced;

  /// No description provided for @animeScoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Score {value}'**
  String animeScoreLabel(String value);

  /// No description provided for @animeEpisodeProgress.
  ///
  /// In en, this message translates to:
  /// **'{aired}/{total} {count, plural, =1{episode} other{episodes}}'**
  String animeEpisodeProgress(String aired, String total, int count);

  /// No description provided for @animeListTitle.
  ///
  /// In en, this message translates to:
  /// **'Anime List'**
  String get animeListTitle;

  /// No description provided for @animeListLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading anime list...'**
  String get animeListLoading;

  /// No description provided for @animeListLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load anime list.'**
  String get animeListLoadError;

  /// No description provided for @animeListLoadMoreError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load more anime.'**
  String get animeListLoadMoreError;

  /// No description provided for @animeListSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search anime'**
  String get animeListSearchHint;

  /// No description provided for @animeListFilterSortButton.
  ///
  /// In en, this message translates to:
  /// **'Filter & Sort'**
  String get animeListFilterSortButton;

  /// No description provided for @animeListFilterSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter & Sort'**
  String get animeListFilterSortTitle;

  /// No description provided for @animeListSortSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get animeListSortSectionTitle;

  /// No description provided for @animeListTypeSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get animeListTypeSectionTitle;

  /// No description provided for @animeListStatusSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get animeListStatusSectionTitle;

  /// No description provided for @animeListSortPopularity.
  ///
  /// In en, this message translates to:
  /// **'Popularity'**
  String get animeListSortPopularity;

  /// No description provided for @animeListSortScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get animeListSortScore;

  /// No description provided for @animeListSortAiredOn.
  ///
  /// In en, this message translates to:
  /// **'Aired On'**
  String get animeListSortAiredOn;

  /// No description provided for @animeListApplyButton.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get animeListApplyButton;

  /// No description provided for @animeListResetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get animeListResetButton;

  /// No description provided for @animeListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No anime available right now.'**
  String get animeListEmpty;

  /// No description provided for @animeListSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No anime found for your search.'**
  String get animeListSearchEmpty;

  /// No description provided for @animeListCriteriaEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for selected criteria.'**
  String get animeListCriteriaEmpty;

  /// No description provided for @animeDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Anime Details'**
  String get animeDetailsTitle;

  /// No description provided for @animeDetailsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading anime details...'**
  String get animeDetailsLoading;

  /// No description provided for @animeDetailsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load anime details.'**
  String get animeDetailsLoadError;

  /// No description provided for @watchSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch Sources'**
  String get watchSourcesTitle;

  /// No description provided for @watchSourcesOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watchSourcesOpenButton;

  /// No description provided for @watchSourcesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading watch sources...'**
  String get watchSourcesLoading;

  /// No description provided for @watchSourcesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load watch sources.'**
  String get watchSourcesLoadError;

  /// No description provided for @watchSourcesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No watch sources found.'**
  String get watchSourcesEmpty;

  /// No description provided for @watchSourcesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search sources'**
  String get watchSourcesSearchHint;

  /// No description provided for @watchSourcesSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No watch sources match your search.'**
  String get watchSourcesSearchEmpty;

  /// No description provided for @watchSourcesSortButton.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get watchSourcesSortButton;

  /// No description provided for @watchSourcesSortSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get watchSourcesSortSheetTitle;

  /// No description provided for @watchSourcesSortApplyButton.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get watchSourcesSortApplyButton;

  /// No description provided for @watchSourcesSortSeeders.
  ///
  /// In en, this message translates to:
  /// **'Seeders'**
  String get watchSourcesSortSeeders;

  /// No description provided for @watchSourcesSortPublishedAt.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get watchSourcesSortPublishedAt;

  /// No description provided for @watchSourcesSortDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get watchSourcesSortDownloads;

  /// No description provided for @watchSourcesSortTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get watchSourcesSortTitle;

  /// No description provided for @watchSourcesSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get watchSourcesSizeLabel;

  /// No description provided for @watchSourcesTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get watchSourcesTimeLabel;

  /// No description provided for @watchSourcesSeedersLabel.
  ///
  /// In en, this message translates to:
  /// **'Seeders'**
  String get watchSourcesSeedersLabel;

  /// No description provided for @watchSourcesLeechersLabel.
  ///
  /// In en, this message translates to:
  /// **'Leechers'**
  String get watchSourcesLeechersLabel;

  /// No description provided for @watchSourcesDownloadsLabel.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get watchSourcesDownloadsLabel;

  /// No description provided for @watchSourcesPageLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Page Link'**
  String get watchSourcesPageLinkLabel;

  /// No description provided for @watchSourcesTorrentLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Torrent Link'**
  String get watchSourcesTorrentLinkLabel;

  /// No description provided for @watchSourcesMagnetLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Magnet Link'**
  String get watchSourcesMagnetLinkLabel;

  /// No description provided for @playerTitle.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerTitle;

  /// No description provided for @playerOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerOpenButton;

  /// No description provided for @playerSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get playerSourceTitle;

  /// No description provided for @playerSourcePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing torrent files...'**
  String get playerSourcePreparing;

  /// No description provided for @playerSourceUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This source is not suitable for playback.'**
  String get playerSourceUnsupported;

  /// No description provided for @playerSourceUnableToPrepare.
  ///
  /// In en, this message translates to:
  /// **'Unable to prepare this source.'**
  String get playerSourceUnableToPrepare;

  /// No description provided for @playerWatchFileButton.
  ///
  /// In en, this message translates to:
  /// **'Watch File'**
  String get playerWatchFileButton;

  /// No description provided for @playerFileSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get playerFileSizeLabel;

  /// No description provided for @playerFileTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get playerFileTypeLabel;

  /// No description provided for @playerPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing video...'**
  String get playerPreparing;

  /// No description provided for @playerWaitingMetadata.
  ///
  /// In en, this message translates to:
  /// **'Looking for torrent metadata...'**
  String get playerWaitingMetadata;

  /// No description provided for @playerBuffering.
  ///
  /// In en, this message translates to:
  /// **'Buffering...'**
  String get playerBuffering;

  /// No description provided for @playerPreparingMoreBuffer.
  ///
  /// In en, this message translates to:
  /// **'Collecting more buffered data...'**
  String get playerPreparingMoreBuffer;

  /// No description provided for @playerStreamPreparationProgress.
  ///
  /// In en, this message translates to:
  /// **'{percent}% ready for playback'**
  String playerStreamPreparationProgress(int percent);

  /// No description provided for @playerStreamPreparationSpeed.
  ///
  /// In en, this message translates to:
  /// **'Current speed: {value}'**
  String playerStreamPreparationSpeed(String value);

  /// No description provided for @playerRuntimeStatsSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed {value}'**
  String playerRuntimeStatsSpeed(String value);

  /// No description provided for @playerRuntimeStatsMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory {value}'**
  String playerRuntimeStatsMemory(String value);

  /// No description provided for @playerRuntimeStatsPeers.
  ///
  /// In en, this message translates to:
  /// **'Peers {value}'**
  String playerRuntimeStatsPeers(String value);

  /// No description provided for @playerRuntimeStatsVideoCodec.
  ///
  /// In en, this message translates to:
  /// **'Video {value}'**
  String playerRuntimeStatsVideoCodec(String value);

  /// No description provided for @playerRuntimeStatsAudioCodec.
  ///
  /// In en, this message translates to:
  /// **'Audio {value}'**
  String playerRuntimeStatsAudioCodec(String value);

  /// No description provided for @playerUnableToStart.
  ///
  /// In en, this message translates to:
  /// **'Unable to start playback.'**
  String get playerUnableToStart;

  /// No description provided for @playerUnableToPrepareFirstFrame.
  ///
  /// In en, this message translates to:
  /// **'The stream is open, but the player could not prepare the first frame.'**
  String get playerUnableToPrepareFirstFrame;

  /// No description provided for @playerUnableToBufferForStart.
  ///
  /// In en, this message translates to:
  /// **'Unable to prepare enough buffered data to start playback.'**
  String get playerUnableToBufferForStart;

  /// No description provided for @playerNoPlayableVideo.
  ///
  /// In en, this message translates to:
  /// **'No playable video found.'**
  String get playerNoPlayableVideo;

  /// No description provided for @playerTracksTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback Tracks'**
  String get playerTracksTitle;

  /// No description provided for @playerAudioTracksTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get playerAudioTracksTitle;

  /// No description provided for @playerSubtitleTracksTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get playerSubtitleTracksTitle;

  /// No description provided for @playerSubtitleAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Appearance'**
  String get playerSubtitleAppearanceTitle;

  /// No description provided for @playerSubtitleVisibilityLabel.
  ///
  /// In en, this message translates to:
  /// **'Show subtitles'**
  String get playerSubtitleVisibilityLabel;

  /// No description provided for @playerSubtitleLibassLabel.
  ///
  /// In en, this message translates to:
  /// **'Improved ASS/SSA rendering'**
  String get playerSubtitleLibassLabel;

  /// No description provided for @playerSubtitleLibassDescription.
  ///
  /// In en, this message translates to:
  /// **'Uses native subtitle rendering for better compatibility with anime releases.'**
  String get playerSubtitleLibassDescription;

  /// No description provided for @playerSubtitleSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get playerSubtitleSizeLabel;

  /// No description provided for @playerSubtitleColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get playerSubtitleColorLabel;

  /// No description provided for @playerSubtitleBackgroundLabel.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get playerSubtitleBackgroundLabel;

  /// No description provided for @playerSubtitlePositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get playerSubtitlePositionLabel;

  /// No description provided for @playerSubtitleResetAction.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get playerSubtitleResetAction;

  /// No description provided for @playerSubtitleColorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get playerSubtitleColorWhite;

  /// No description provided for @playerSubtitleColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get playerSubtitleColorYellow;

  /// No description provided for @playerSubtitleColorCyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get playerSubtitleColorCyan;

  /// No description provided for @playerSubtitleBackgroundNone.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playerSubtitleBackgroundNone;

  /// No description provided for @playerSubtitleBackgroundTranslucent.
  ///
  /// In en, this message translates to:
  /// **'Translucent'**
  String get playerSubtitleBackgroundTranslucent;

  /// No description provided for @playerSubtitleBackgroundSolid.
  ///
  /// In en, this message translates to:
  /// **'Solid'**
  String get playerSubtitleBackgroundSolid;

  /// No description provided for @playerSubtitlePositionLow.
  ///
  /// In en, this message translates to:
  /// **'Lower'**
  String get playerSubtitlePositionLow;

  /// No description provided for @playerSubtitlePositionStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get playerSubtitlePositionStandard;

  /// No description provided for @playerSubtitlePositionHigh.
  ///
  /// In en, this message translates to:
  /// **'Higher'**
  String get playerSubtitlePositionHigh;

  /// No description provided for @playerTrackAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get playerTrackAuto;

  /// No description provided for @playerTrackOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get playerTrackOff;

  /// No description provided for @playerTracksUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get playerTracksUnavailable;

  /// No description provided for @invalidRouteArgumentsMessage.
  ///
  /// In en, this message translates to:
  /// **'This screen was opened with invalid navigation data.'**
  String get invalidRouteArgumentsMessage;

  /// No description provided for @playerPlayButton.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlayButton;

  /// No description provided for @playerPauseButton.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPauseButton;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
