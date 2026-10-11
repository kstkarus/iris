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

  /// No description provided for @navigationCatalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get navigationCatalog;

  /// No description provided for @navigationDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get navigationDownloads;

  /// No description provided for @downloadsOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadsOpenButton;

  /// No description provided for @downloadsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Episodes download from a title’s sources, or from Torrents.'**
  String get downloadsEmpty;

  /// No description provided for @downloadSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Download a file'**
  String get downloadSelectionTitle;

  /// No description provided for @downloadSelectionPreparing.
  ///
  /// In en, this message translates to:
  /// **'Loading torrent file list...'**
  String get downloadSelectionPreparing;

  /// No description provided for @downloadSelectionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This source has no supported video files.'**
  String get downloadSelectionUnsupported;

  /// No description provided for @downloadSelectionUnableToPrepare.
  ///
  /// In en, this message translates to:
  /// **'Unable to load files from this source.'**
  String get downloadSelectionUnableToPrepare;

  /// No description provided for @downloadUnableToQueue.
  ///
  /// In en, this message translates to:
  /// **'Unable to add this file to the download queue.'**
  String get downloadUnableToQueue;

  /// No description provided for @downloadFileButton.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadFileButton;

  /// No description provided for @downloadAddingToQueue.
  ///
  /// In en, this message translates to:
  /// **'Adding to queue...'**
  String get downloadAddingToQueue;

  /// No description provided for @downloadManagerUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load downloads.'**
  String get downloadManagerUnableToLoad;

  /// No description provided for @downloadStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'App storage'**
  String get downloadStorageTitle;

  /// No description provided for @downloadStorageTotal.
  ///
  /// In en, this message translates to:
  /// **'Total used by app'**
  String get downloadStorageTotal;

  /// No description provided for @downloadStorageContent.
  ///
  /// In en, this message translates to:
  /// **'Offline content'**
  String get downloadStorageContent;

  /// No description provided for @downloadStorageCache.
  ///
  /// In en, this message translates to:
  /// **'Online viewing cache'**
  String get downloadStorageCache;

  /// No description provided for @downloadStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get downloadStatusQueued;

  /// No description provided for @downloadStatusDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadStatusDownloading;

  /// No description provided for @downloadStatusPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get downloadStatusPaused;

  /// No description provided for @downloadStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get downloadStatusCompleted;

  /// No description provided for @downloadStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get downloadStatusFailed;

  /// No description provided for @downloadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'The torrent stopped with an error. Try again later.'**
  String get downloadFailedMessage;

  /// No description provided for @downloadWatchButton.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get downloadWatchButton;

  /// No description provided for @downloadPauseButton.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get downloadPauseButton;

  /// No description provided for @downloadResumeButton.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get downloadResumeButton;

  /// No description provided for @downloadDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get downloadDeleteButton;

  /// No description provided for @downloadCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get downloadCancelButton;

  /// No description provided for @downloadDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete download?'**
  String get downloadDeleteTitle;

  /// No description provided for @downloadDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'“{name}” will be removed from the device.'**
  String downloadDeleteMessage(String name);

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
  /// **'Watch sources'**
  String get watchSourcesTitle;

  /// No description provided for @watchSourcesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading sources...'**
  String get watchSourcesLoading;

  /// No description provided for @watchSourcesLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load sources.'**
  String get watchSourcesLoadError;

  /// No description provided for @watchSourcesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sources found.'**
  String get watchSourcesEmpty;

  /// No description provided for @watchSourcesOnlineSection.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get watchSourcesOnlineSection;

  /// No description provided for @watchSourcesTorrentsSection.
  ///
  /// In en, this message translates to:
  /// **'Torrents'**
  String get watchSourcesTorrentsSection;

  /// No description provided for @watchSourcesOnlineLoading.
  ///
  /// In en, this message translates to:
  /// **'Looking for online sources'**
  String get watchSourcesOnlineLoading;

  /// No description provided for @watchSourcesOnlineLoadError.
  ///
  /// In en, this message translates to:
  /// **'Online sources did not respond.'**
  String get watchSourcesOnlineLoadError;

  /// No description provided for @watchSourcesOnlineBestQuality.
  ///
  /// In en, this message translates to:
  /// **'up to {quality}p'**
  String watchSourcesOnlineBestQuality(int quality);

  /// No description provided for @watchSourcesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search sources'**
  String get watchSourcesSearchHint;

  /// No description provided for @watchSourcesSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No sources match your search.'**
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

  /// No description provided for @playerSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose File'**
  String get playerSourceTitle;

  /// No description provided for @playerSourcePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing torrent files'**
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

  /// No description provided for @playerSourceEpisodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an episode'**
  String get playerSourceEpisodesTitle;

  /// No description provided for @playerSourceEpisodesPreparing.
  ///
  /// In en, this message translates to:
  /// **'Loading episodes'**
  String get playerSourceEpisodesPreparing;

  /// No description provided for @playerEpisodeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String playerEpisodeMinutes(int minutes);

  /// No description provided for @playerPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing video'**
  String get playerPreparing;

  /// No description provided for @playerBuffering.
  ///
  /// In en, this message translates to:
  /// **'Buffering'**
  String get playerBuffering;

  /// No description provided for @playerWaitNoPeers.
  ///
  /// In en, this message translates to:
  /// **'No peers yet'**
  String get playerWaitNoPeers;

  /// No description provided for @playerWaitPeers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 peer} other{{count} peers}}'**
  String playerWaitPeers(int count);

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

  /// No description provided for @playerSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get playerSettingsTitle;

  /// No description provided for @playerDecoderSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Decoder'**
  String get playerDecoderSettingsTitle;

  /// No description provided for @playerDecoderSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Change this only if video stutters or shows green frames on your device. Technical details below show the decoder in use.'**
  String get playerDecoderSettingsDescription;

  /// No description provided for @playerDecoderAutoSafe.
  ///
  /// In en, this message translates to:
  /// **'Auto (recommended)'**
  String get playerDecoderAutoSafe;

  /// No description provided for @playerDecoderMediacodec.
  ///
  /// In en, this message translates to:
  /// **'MediaCodec'**
  String get playerDecoderMediacodec;

  /// No description provided for @playerDecoderMediacodecCopy.
  ///
  /// In en, this message translates to:
  /// **'MediaCodec (copy-back)'**
  String get playerDecoderMediacodecCopy;

  /// No description provided for @playerDecoderSoftwareOnly.
  ///
  /// In en, this message translates to:
  /// **'Software only'**
  String get playerDecoderSoftwareOnly;

  /// No description provided for @playerSubtitleAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Appearance'**
  String get playerSubtitleAppearanceTitle;

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

  /// No description provided for @playerSubtitleSizeSample.
  ///
  /// In en, this message translates to:
  /// **'Aa'**
  String get playerSubtitleSizeSample;

  /// No description provided for @playerSubtitleSizeSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get playerSubtitleSizeSmaller;

  /// No description provided for @playerSubtitleSizeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get playerSubtitleSizeNormal;

  /// No description provided for @playerSubtitleSizeLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get playerSubtitleSizeLarger;

  /// No description provided for @playerSubtitleSizeLargest.
  ///
  /// In en, this message translates to:
  /// **'Largest'**
  String get playerSubtitleSizeLargest;

  /// No description provided for @playerSubtitleOverrideHint.
  ///
  /// In en, this message translates to:
  /// **'A custom colour, background or position replaces the release\'s styling: styled signs become plain text.'**
  String get playerSubtitleOverrideHint;

  /// No description provided for @playerAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get playerAdvancedTitle;

  /// No description provided for @playerAdvancedSummary.
  ///
  /// In en, this message translates to:
  /// **'Decoder: {decoder} · ASS rendering: {ass}'**
  String playerAdvancedSummary(String decoder, String ass);

  /// No description provided for @playerSettingOn.
  ///
  /// In en, this message translates to:
  /// **'on'**
  String get playerSettingOn;

  /// No description provided for @playerSettingOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get playerSettingOff;

  /// No description provided for @playerDecoderAutoShort.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get playerDecoderAutoShort;

  /// No description provided for @playerRestartHint.
  ///
  /// In en, this message translates to:
  /// **'The decoder and ASS rendering apply by restarting the video where it is.'**
  String get playerRestartHint;

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

  /// No description provided for @navigationSavedTorrents.
  ///
  /// In en, this message translates to:
  /// **'Torrents'**
  String get navigationSavedTorrents;

  /// No description provided for @savedTorrentsAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add torrent'**
  String get savedTorrentsAddButton;

  /// No description provided for @savedTorrentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved torrents yet'**
  String get savedTorrentsEmptyTitle;

  /// No description provided for @savedTorrentsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add one by its magnet link to stream or download it. Added torrents stay here.'**
  String get savedTorrentsEmptyMessage;

  /// No description provided for @savedTorrentsAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add torrent'**
  String get savedTorrentsAddTitle;

  /// No description provided for @savedTorrentsMagnetLabel.
  ///
  /// In en, this message translates to:
  /// **'Magnet link'**
  String get savedTorrentsMagnetLabel;

  /// No description provided for @savedTorrentsPasteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get savedTorrentsPasteTooltip;

  /// No description provided for @savedTorrentsNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get savedTorrentsNameLabel;

  /// No description provided for @savedTorrentsNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Taken from the link if left empty'**
  String get savedTorrentsNameHelper;

  /// No description provided for @savedTorrentsInvalidMagnet.
  ///
  /// In en, this message translates to:
  /// **'Not a magnet link with a torrent hash (xt=urn:btih:…).'**
  String get savedTorrentsInvalidMagnet;

  /// No description provided for @savedTorrentsSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get savedTorrentsSaveButton;

  /// No description provided for @savedTorrentsAdded.
  ///
  /// In en, this message translates to:
  /// **'Torrent added'**
  String get savedTorrentsAdded;

  /// No description provided for @savedTorrentsDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Already added as “{title}”'**
  String savedTorrentsDuplicate(String title);

  /// No description provided for @commonMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get commonMoreActions;

  /// No description provided for @savedTorrentsRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get savedTorrentsRename;

  /// No description provided for @savedTorrentsCopyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get savedTorrentsCopyLink;

  /// No description provided for @savedTorrentsLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get savedTorrentsLinkCopied;

  /// No description provided for @savedTorrentsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get savedTorrentsDelete;

  /// No description provided for @savedTorrentsAddedOn.
  ///
  /// In en, this message translates to:
  /// **'Added {date}'**
  String savedTorrentsAddedOn(String date);

  /// No description provided for @savedTorrentsOpenedOn.
  ///
  /// In en, this message translates to:
  /// **'Opened {date}'**
  String savedTorrentsOpenedOn(String date);

  /// No description provided for @downloadStorageClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get downloadStorageClearCache;

  /// No description provided for @downloadStorageCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get downloadStorageCacheCleared;

  /// No description provided for @downloadStorageCacheBusy.
  ///
  /// In en, this message translates to:
  /// **'The cache is in use while a video is playing'**
  String get downloadStorageCacheBusy;

  /// No description provided for @downloadsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading downloaded files...'**
  String get downloadsLoading;

  /// No description provided for @savedTorrentsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading saved torrents...'**
  String get savedTorrentsLoading;

  /// No description provided for @downloadDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to delete the files. Close the file if it is open and try again'**
  String get downloadDeleteFailed;

  /// No description provided for @playerResumedFrom.
  ///
  /// In en, this message translates to:
  /// **'Resumed from {position}'**
  String playerResumedFrom(String position);

  /// No description provided for @playerStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get playerStartOver;

  /// No description provided for @playerResumingFrom.
  ///
  /// In en, this message translates to:
  /// **'Picking up at {position}'**
  String playerResumingFrom(String position);

  /// No description provided for @playerStartingOver.
  ///
  /// In en, this message translates to:
  /// **'Starting from the beginning'**
  String get playerStartingOver;

  /// No description provided for @playerStartedOver.
  ///
  /// In en, this message translates to:
  /// **'Playing from the beginning'**
  String get playerStartedOver;

  /// No description provided for @playerResumeFromAction.
  ///
  /// In en, this message translates to:
  /// **'From {position}'**
  String playerResumeFromAction(String position);

  /// No description provided for @playerPlayNext.
  ///
  /// In en, this message translates to:
  /// **'Next episode'**
  String get playerPlayNext;

  /// No description provided for @playerSkipOpening.
  ///
  /// In en, this message translates to:
  /// **'Skip opening'**
  String get playerSkipOpening;

  /// No description provided for @playerSkipRecap.
  ///
  /// In en, this message translates to:
  /// **'Skip recap'**
  String get playerSkipRecap;

  /// No description provided for @playerSkipForward.
  ///
  /// In en, this message translates to:
  /// **'+{seconds} s'**
  String playerSkipForward(int seconds);

  /// No description provided for @playerSkipForwardTooltip.
  ///
  /// In en, this message translates to:
  /// **'Skip {seconds} seconds'**
  String playerSkipForwardTooltip(int seconds);

  /// No description provided for @watchProgressWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get watchProgressWatched;

  /// No description provided for @watchProgressStoppedAt.
  ///
  /// In en, this message translates to:
  /// **'Stopped at {position} of {duration}'**
  String watchProgressStoppedAt(String position, String duration);

  /// No description provided for @watchProgressContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get watchProgressContinueButton;

  /// No description provided for @watchProgressPlayNextButton.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get watchProgressPlayNextButton;

  /// No description provided for @watchProgressWatchButton.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watchProgressWatchButton;

  /// No description provided for @watchProgressLastFile.
  ///
  /// In en, this message translates to:
  /// **'Last watched: {fileName}'**
  String watchProgressLastFile(String fileName);

  /// No description provided for @continueWatchingTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get continueWatchingTitle;

  /// No description provided for @continueWatchingRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get continueWatchingRemove;

  /// No description provided for @continueWatchingStoppedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Stopped at'**
  String get continueWatchingStoppedAtLabel;

  /// No description provided for @continueWatchingFinishedLabel.
  ///
  /// In en, this message translates to:
  /// **'Watched to the end'**
  String get continueWatchingFinishedLabel;

  /// No description provided for @animeListHeadingPopularity.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get animeListHeadingPopularity;

  /// No description provided for @animeListHeadingScore.
  ///
  /// In en, this message translates to:
  /// **'Top rated'**
  String get animeListHeadingScore;

  /// No description provided for @animeListHeadingAiredOn.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get animeListHeadingAiredOn;

  /// No description provided for @recentlyWatchedTitle.
  ///
  /// In en, this message translates to:
  /// **'Recently watched'**
  String get recentlyWatchedTitle;

  /// No description provided for @watchSourceUsedBadge.
  ///
  /// In en, this message translates to:
  /// **'You watched this'**
  String get watchSourceUsedBadge;

  /// No description provided for @playerEpisodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get playerEpisodesTitle;

  /// No description provided for @playerShowEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Show episodes'**
  String get playerShowEpisodes;

  /// No description provided for @playerHideEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Hide episodes'**
  String get playerHideEpisodes;

  /// No description provided for @playerNowPlaying.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get playerNowPlaying;

  /// No description provided for @playerDetailedStats.
  ///
  /// In en, this message translates to:
  /// **'Technical details'**
  String get playerDetailedStats;

  /// No description provided for @playerDetailedStatsHint.
  ///
  /// In en, this message translates to:
  /// **'Peers, decoder and codecs over the video'**
  String get playerDetailedStatsHint;

  /// No description provided for @playerBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get playerBack;

  /// No description provided for @playerEpisodeNumber.
  ///
  /// In en, this message translates to:
  /// **'Episode {number}'**
  String playerEpisodeNumber(int number);

  /// No description provided for @playerEpisodePosition.
  ///
  /// In en, this message translates to:
  /// **'{position} of {total}'**
  String playerEpisodePosition(int position, int total);

  /// No description provided for @playerEpisodeOfTotal.
  ///
  /// In en, this message translates to:
  /// **'of {total}'**
  String playerEpisodeOfTotal(int total);

  /// No description provided for @playerTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'{time} left'**
  String playerTimeLeft(String time);

  /// No description provided for @playerSeekBackward.
  ///
  /// In en, this message translates to:
  /// **'Back {seconds} s'**
  String playerSeekBackward(int seconds);

  /// No description provided for @playerSeekForward.
  ///
  /// In en, this message translates to:
  /// **'Forward {seconds} s'**
  String playerSeekForward(int seconds);

  /// No description provided for @playerMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get playerMute;

  /// No description provided for @playerUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get playerUnmute;

  /// No description provided for @playerAudioAndSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Audio & subtitles'**
  String get playerAudioAndSubtitles;

  /// No description provided for @playerEnterFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get playerEnterFullscreen;

  /// No description provided for @playerExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get playerExitFullscreen;

  /// No description provided for @playerCloseEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Close episodes'**
  String get playerCloseEpisodes;

  /// No description provided for @playerRate.
  ///
  /// In en, this message translates to:
  /// **'{value}/s'**
  String playerRate(String value);

  /// No description provided for @byteUnitB.
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get byteUnitB;

  /// No description provided for @byteUnitKB.
  ///
  /// In en, this message translates to:
  /// **'KB'**
  String get byteUnitKB;

  /// No description provided for @byteUnitMB.
  ///
  /// In en, this message translates to:
  /// **'MB'**
  String get byteUnitMB;

  /// No description provided for @byteUnitGB.
  ///
  /// In en, this message translates to:
  /// **'GB'**
  String get byteUnitGB;

  /// No description provided for @playerTimePosition.
  ///
  /// In en, this message translates to:
  /// **'{position} of {duration}'**
  String playerTimePosition(String position, String duration);

  /// No description provided for @playerSeekBarLabel.
  ///
  /// In en, this message translates to:
  /// **'Playback position'**
  String get playerSeekBarLabel;

  /// No description provided for @animeDetailsChooseSourceButton.
  ///
  /// In en, this message translates to:
  /// **'Choose source'**
  String get animeDetailsChooseSourceButton;

  /// No description provided for @animeEpisodeCount.
  ///
  /// In en, this message translates to:
  /// **'{value} {count, plural, =1{episode} other{episodes}}'**
  String animeEpisodeCount(String value, int count);

  /// No description provided for @watchSourceSeeders.
  ///
  /// In en, this message translates to:
  /// **'{value} {count, plural, =1{seeder} other{seeders}}'**
  String watchSourceSeeders(String value, int count);

  /// No description provided for @watchSourceDownloads.
  ///
  /// In en, this message translates to:
  /// **'{value} {count, plural, =1{download} other{downloads}}'**
  String watchSourceDownloads(String value, int count);

  /// No description provided for @searchClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get searchClearTooltip;

  /// No description provided for @searchCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get searchCancelButton;

  /// No description provided for @animeDetailsFactKind.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get animeDetailsFactKind;

  /// No description provided for @animeDetailsFactStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get animeDetailsFactStatus;

  /// No description provided for @animeDetailsFactEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get animeDetailsFactEpisodes;

  /// No description provided for @animeDetailsFactScore.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get animeDetailsFactScore;

  /// No description provided for @animeDetailsFactAired.
  ///
  /// In en, this message translates to:
  /// **'Aired'**
  String get animeDetailsFactAired;

  /// No description provided for @animeDetailsEpisodesAired.
  ///
  /// In en, this message translates to:
  /// **'{aired} of {total}'**
  String animeDetailsEpisodesAired(String aired, String total);

  /// No description provided for @animeDetailsDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get animeDetailsDescriptionTitle;

  /// No description provided for @animeDetailsShowCover.
  ///
  /// In en, this message translates to:
  /// **'Show the original cover'**
  String get animeDetailsShowCover;

  /// No description provided for @animeDetailsShowHalftone.
  ///
  /// In en, this message translates to:
  /// **'Show the halftone'**
  String get animeDetailsShowHalftone;

  /// No description provided for @watchSourcesColumnRelease.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get watchSourcesColumnRelease;

  /// No description provided for @watchSourcesColumnSize.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get watchSourcesColumnSize;

  /// No description provided for @watchSourcesColumnSeeders.
  ///
  /// In en, this message translates to:
  /// **'Seeders'**
  String get watchSourcesColumnSeeders;

  /// No description provided for @watchSourcesColumnDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get watchSourcesColumnDownloads;

  /// No description provided for @watchSourcesColumnDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get watchSourcesColumnDate;

  /// No description provided for @savedTorrentsPasteHint.
  ///
  /// In en, this message translates to:
  /// **'{shortcut} adds a torrent from the clipboard'**
  String savedTorrentsPasteHint(String shortcut);

  /// No description provided for @downloadsFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get downloadsFilesTitle;

  /// Unfolds the rest of a list.
  ///
  /// In en, this message translates to:
  /// **'{count} more'**
  String commonShowMore(int count);

  /// No description provided for @commonShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get commonShowLess;

  /// No description provided for @animeKindSpecial.
  ///
  /// In en, this message translates to:
  /// **'Special'**
  String get animeKindSpecial;

  /// No description provided for @animeKindTvSpecial.
  ///
  /// In en, this message translates to:
  /// **'TV special'**
  String get animeKindTvSpecial;

  /// No description provided for @animeDetailsRelatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Related'**
  String get animeDetailsRelatedTitle;

  /// No description provided for @animeRelationPrequel.
  ///
  /// In en, this message translates to:
  /// **'Prequel'**
  String get animeRelationPrequel;

  /// No description provided for @animeRelationSequel.
  ///
  /// In en, this message translates to:
  /// **'Sequel'**
  String get animeRelationSequel;

  /// No description provided for @animeRelationParentStory.
  ///
  /// In en, this message translates to:
  /// **'Parent story'**
  String get animeRelationParentStory;

  /// No description provided for @animeRelationFullStory.
  ///
  /// In en, this message translates to:
  /// **'Full story'**
  String get animeRelationFullStory;

  /// No description provided for @animeRelationSideStory.
  ///
  /// In en, this message translates to:
  /// **'Side story'**
  String get animeRelationSideStory;

  /// No description provided for @animeRelationAlternativeSetting.
  ///
  /// In en, this message translates to:
  /// **'Alternative setting'**
  String get animeRelationAlternativeSetting;

  /// No description provided for @animeRelationAlternativeVersion.
  ///
  /// In en, this message translates to:
  /// **'Alternative version'**
  String get animeRelationAlternativeVersion;

  /// No description provided for @animeRelationSpinOff.
  ///
  /// In en, this message translates to:
  /// **'Spin-off'**
  String get animeRelationSpinOff;

  /// No description provided for @animeRelationSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get animeRelationSummary;

  /// No description provided for @animeRelationCharacter.
  ///
  /// In en, this message translates to:
  /// **'Shared characters'**
  String get animeRelationCharacter;

  /// No description provided for @animeRelationOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get animeRelationOther;

  /// No description provided for @navigationProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navigationProfile;

  /// No description provided for @profileSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Shikimori list'**
  String get profileSignInTitle;

  /// No description provided for @profileSignInMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to mark anime in your Shikimori list right from the app.'**
  String get profileSignInMessage;

  /// No description provided for @profileSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Shikimori'**
  String get profileSignInButton;

  /// No description provided for @profileSignInUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is not set up in this build.'**
  String get profileSignInUnavailable;

  /// No description provided for @profileSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Shikimori'**
  String get profileSigningIn;

  /// No description provided for @profileSignInNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Shikimori did not respond. Try again.'**
  String get profileSignInNetworkError;

  /// No description provided for @profileSignInRejected.
  ///
  /// In en, this message translates to:
  /// **'Shikimori did not let the app in. Try again.'**
  String get profileSignInRejected;

  /// No description provided for @profileSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Shikimori ended the session. Sign in again.'**
  String get profileSessionExpired;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOut;

  /// No description provided for @userRateTitle.
  ///
  /// In en, this message translates to:
  /// **'My list'**
  String get userRateTitle;

  /// No description provided for @userRateAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get userRateAdd;

  /// No description provided for @userRateRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get userRateRemove;

  /// No description provided for @userRateStatusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get userRateStatusPlanned;

  /// No description provided for @userRateStatusWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get userRateStatusWatching;

  /// No description provided for @userRateStatusRewatching.
  ///
  /// In en, this message translates to:
  /// **'Rewatching'**
  String get userRateStatusRewatching;

  /// No description provided for @userRateStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get userRateStatusCompleted;

  /// No description provided for @userRateStatusOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get userRateStatusOnHold;

  /// No description provided for @userRateStatusDropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get userRateStatusDropped;

  /// No description provided for @userRateEpisodeLess.
  ///
  /// In en, this message translates to:
  /// **'One episode less'**
  String get userRateEpisodeLess;

  /// No description provided for @userRateEpisodeMore.
  ///
  /// In en, this message translates to:
  /// **'One more episode'**
  String get userRateEpisodeMore;

  /// No description provided for @userRateEpisodesWatched.
  ///
  /// In en, this message translates to:
  /// **'Episodes watched: {count}'**
  String userRateEpisodesWatched(String count);

  /// No description provided for @userRateLoadError.
  ///
  /// In en, this message translates to:
  /// **'Your list did not load.'**
  String get userRateLoadError;

  /// No description provided for @userRateSaveError.
  ///
  /// In en, this message translates to:
  /// **'Shikimori did not save the change.'**
  String get userRateSaveError;

  /// No description provided for @userRateScore.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String userRateScore(int score);

  /// No description provided for @userRateRate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get userRateRate;

  /// No description provided for @userRateNoScore.
  ///
  /// In en, this message translates to:
  /// **'No score'**
  String get userRateNoScore;

  /// No description provided for @animeListHideCompleted.
  ///
  /// In en, this message translates to:
  /// **'Not completed'**
  String get animeListHideCompleted;

  /// No description provided for @animeListGenresSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get animeListGenresSectionTitle;

  /// No description provided for @animeListShowThemes.
  ///
  /// In en, this message translates to:
  /// **'Themes ({count})'**
  String animeListShowThemes(int count);

  /// No description provided for @animeListSeasonSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get animeListSeasonSectionTitle;

  /// No description provided for @animeSeasonWinter.
  ///
  /// In en, this message translates to:
  /// **'Winter {year}'**
  String animeSeasonWinter(String year);

  /// No description provided for @animeSeasonSpring.
  ///
  /// In en, this message translates to:
  /// **'Spring {year}'**
  String animeSeasonSpring(String year);

  /// No description provided for @animeSeasonSummer.
  ///
  /// In en, this message translates to:
  /// **'Summer {year}'**
  String animeSeasonSummer(String year);

  /// No description provided for @animeSeasonFall.
  ///
  /// In en, this message translates to:
  /// **'Fall {year}'**
  String animeSeasonFall(String year);

  /// No description provided for @animeListDecade.
  ///
  /// In en, this message translates to:
  /// **'{decade}s'**
  String animeListDecade(String decade);

  /// No description provided for @animeListBefore2000.
  ///
  /// In en, this message translates to:
  /// **'Before 2000'**
  String get animeListBefore2000;

  /// No description provided for @animeListRatingSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Age rating'**
  String get animeListRatingSectionTitle;

  /// No description provided for @animeListDurationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Episode length'**
  String get animeListDurationSectionTitle;

  /// No description provided for @animeDurationShort.
  ///
  /// In en, this message translates to:
  /// **'Under 10 min'**
  String get animeDurationShort;

  /// No description provided for @animeDurationStandard.
  ///
  /// In en, this message translates to:
  /// **'Under 30 min'**
  String get animeDurationStandard;

  /// No description provided for @animeDurationLong.
  ///
  /// In en, this message translates to:
  /// **'Over 30 min'**
  String get animeDurationLong;

  /// No description provided for @animeNextEpisodeToday.
  ///
  /// In en, this message translates to:
  /// **'today at {time}'**
  String animeNextEpisodeToday(String time);

  /// No description provided for @animeNextEpisodeTomorrow.
  ///
  /// In en, this message translates to:
  /// **'tomorrow at {time}'**
  String animeNextEpisodeTomorrow(String time);

  /// No description provided for @animeNextEpisodeInDays.
  ///
  /// In en, this message translates to:
  /// **'in {count, plural, one{{count} day} other{{count} days}}'**
  String animeNextEpisodeInDays(int count);

  /// No description provided for @animeNextEpisode.
  ///
  /// In en, this message translates to:
  /// **'Episode {episode} {when}'**
  String animeNextEpisode(int episode, String when);

  /// No description provided for @profileListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing in “{status}”'**
  String profileListEmpty(String status);

  /// No description provided for @profileListLoadError.
  ///
  /// In en, this message translates to:
  /// **'The list did not load.'**
  String get profileListLoadError;

  /// No description provided for @profileListLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the list'**
  String get profileListLoading;

  /// No description provided for @profileFriendsTab.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get profileFriendsTab;

  /// No description provided for @profileFriendsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No friends on Shikimori yet.'**
  String get profileFriendsEmpty;

  /// No description provided for @profileFriendsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Friends did not load.'**
  String get profileFriendsLoadError;

  /// No description provided for @profileFriendsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading friends'**
  String get profileFriendsLoading;

  /// No description provided for @animeDetailsFriendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get animeDetailsFriendsTitle;

  /// No description provided for @animeDetailsFactNextEpisode.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get animeDetailsFactNextEpisode;

  /// No description provided for @animeDetailsFactStudio.
  ///
  /// In en, this message translates to:
  /// **'Studio'**
  String get animeDetailsFactStudio;

  /// No description provided for @animeDetailsFactGenres.
  ///
  /// In en, this message translates to:
  /// **'Genres'**
  String get animeDetailsFactGenres;

  /// No description provided for @animeDetailsFactRating.
  ///
  /// In en, this message translates to:
  /// **'Rated'**
  String get animeDetailsFactRating;

  /// No description provided for @animeDetailsDubsTitle.
  ///
  /// In en, this message translates to:
  /// **'Dubs'**
  String get animeDetailsDubsTitle;

  /// No description provided for @playerMarked.
  ///
  /// In en, this message translates to:
  /// **'Episode {episode} marked on Shikimori'**
  String playerMarked(int episode);

  /// No description provided for @playerMarkUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get playerMarkUndo;

  /// No description provided for @playerMarkOffer.
  ///
  /// In en, this message translates to:
  /// **'Mark episode {episode} on Shikimori?'**
  String playerMarkOffer(int episode);

  /// No description provided for @playerMarkAction.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get playerMarkAction;

  /// No description provided for @playerMarkFailed.
  ///
  /// In en, this message translates to:
  /// **'Shikimori did not save the mark.'**
  String get playerMarkFailed;

  /// No description provided for @profileSigningInHint.
  ///
  /// In en, this message translates to:
  /// **'Finish signing in in the browser. Coming back here before that cancels it.'**
  String get profileSigningInHint;

  /// No description provided for @profileSignInPortBusy.
  ///
  /// In en, this message translates to:
  /// **'Another program holds port 43821, which sign-in needs. Close it and try again.'**
  String get profileSignInPortBusy;

  /// No description provided for @profileListTab.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get profileListTab;

  /// No description provided for @profileListEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'The status is set on an anime’s page.'**
  String get profileListEmptyHint;

  /// No description provided for @profileListProgress.
  ///
  /// In en, this message translates to:
  /// **'{watched} of {total} ep.'**
  String profileListProgress(int watched, int total);

  /// No description provided for @profileListWatched.
  ///
  /// In en, this message translates to:
  /// **'{watched} ep.'**
  String profileListWatched(int watched);

  /// No description provided for @commonBrowseCatalog.
  ///
  /// In en, this message translates to:
  /// **'Browse the catalog'**
  String get commonBrowseCatalog;

  /// No description provided for @savedTorrentsAddConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get savedTorrentsAddConfirm;

  /// No description provided for @savedTorrentsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Torrent deleted'**
  String get savedTorrentsDeleted;

  /// No description provided for @savedTorrentsEpisodeWatched.
  ///
  /// In en, this message translates to:
  /// **'Episode {number} watched'**
  String savedTorrentsEpisodeWatched(int number);

  /// No description provided for @savedTorrentsFileWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched: {fileName}'**
  String savedTorrentsFileWatched(String fileName);

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @userRateLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading my list...'**
  String get userRateLoading;

  /// No description provided for @downloadStorageCacheHint.
  ///
  /// In en, this message translates to:
  /// **'Episodes watched without downloading. Clearing it keeps your downloads.'**
  String get downloadStorageCacheHint;

  /// No description provided for @downloadNoPeers.
  ///
  /// In en, this message translates to:
  /// **'no peers yet'**
  String get downloadNoPeers;

  /// No description provided for @downloadTimeLeftUnderMinute.
  ///
  /// In en, this message translates to:
  /// **'< 1 min left'**
  String get downloadTimeLeftUnderMinute;

  /// No description provided for @downloadTimeLeftMinutes.
  ///
  /// In en, this message translates to:
  /// **'~{minutes} min left'**
  String downloadTimeLeftMinutes(int minutes);

  /// No description provided for @downloadTimeLeftHours.
  ///
  /// In en, this message translates to:
  /// **'~{hours} h {minutes} min left'**
  String downloadTimeLeftHours(int hours, int minutes);

  /// No description provided for @downloadFailedNoSpace.
  ///
  /// In en, this message translates to:
  /// **'The device ran out of space. Free some up and try again.'**
  String get downloadFailedNoSpace;

  /// No description provided for @downloadFailedNoAccess.
  ///
  /// In en, this message translates to:
  /// **'The app may not write to the downloads folder.'**
  String get downloadFailedNoAccess;

  /// No description provided for @downloadFailedFileMissing.
  ///
  /// In en, this message translates to:
  /// **'The file is gone from the device. Try again to download it anew.'**
  String get downloadFailedFileMissing;

  /// No description provided for @downloadFailedCouldNotStart.
  ///
  /// In en, this message translates to:
  /// **'The download did not start. Check the connection and try again.'**
  String get downloadFailedCouldNotStart;

  /// No description provided for @downloadDeleteProgressLost.
  ///
  /// In en, this message translates to:
  /// **'The {size} downloaded so far will be lost.'**
  String downloadDeleteProgressLost(String size);

  /// No description provided for @downloadAnnounceCompleted.
  ///
  /// In en, this message translates to:
  /// **'Downloaded: {name}'**
  String downloadAnnounceCompleted(String name);

  /// No description provided for @downloadAnnounceFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {name}'**
  String downloadAnnounceFailed(String name);
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
