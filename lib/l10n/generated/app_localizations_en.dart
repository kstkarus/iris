// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get downloadFilesButton => 'Files';

  @override
  String get downloadFilesTitle => 'Free up space';

  @override
  String get downloadFilesTemporary => 'Temporary files';

  @override
  String get downloadFilesTemporaryHint =>
      'Your downloaded episodes will be kept.';

  @override
  String get downloadFilesTemporaryBusy =>
      'Stop playback to clear these files.';

  @override
  String get downloadFilesClearTemporary => 'Clear temporary files';

  @override
  String get downloadFilesClearingTemporary => 'Clearing temporary files';

  @override
  String get downloadFilesTemporaryCleared => 'Temporary files deleted';

  @override
  String get downloadFilesClearFailed => 'Couldn’t delete temporary files.';

  @override
  String get downloadFilesSaved => 'Downloaded episodes';

  @override
  String get downloadFilesEmpty => 'No downloaded episodes yet.';

  @override
  String get downloadFilesUnavailable => 'Unable to check temporary file size.';

  @override
  String get downloadQueueButton => 'Queue';

  @override
  String get downloadQueueCurrent => 'Downloading now';

  @override
  String get downloadQueueWaiting => 'Up next';

  @override
  String get downloadQueueMoveUp => 'Move up';

  @override
  String get downloadQueueMoveDown => 'Move down';

  @override
  String get downloadQueueMove => 'Move episode';

  @override
  String get downloadQueueChanged => 'Download order changed';

  @override
  String get downloadQueueReorderFailed => 'Couldn’t reorder the queue.';

  @override
  String get downloadQueuePaused => 'Paused';

  @override
  String get downloadQueueAttention => 'Failed';

  @override
  String get downloadQueueFinished => 'All downloads finished.';

  @override
  String get downloadQueueNoWaiting => 'No episodes waiting.';

  @override
  String downloadBytesProgress(String downloaded, String total) {
    return '$downloaded of $total';
  }

  @override
  String downloadBytesDownloaded(String size) {
    return '$size downloaded';
  }

  @override
  String get appName => 'Iris';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonSignIn => 'Sign in';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String get navigationCatalog => 'Catalog';

  @override
  String get navigationDownloads => 'Downloads';

  @override
  String get navigationDownloadsActive => 'downloading';

  @override
  String get downloadsOpenButton => 'Download';

  @override
  String get downloadsEmptyTitle => 'No downloads yet';

  @override
  String get downloadsEmpty =>
      'Download episodes from an anime’s page to watch offline.';

  @override
  String get downloadSelectionTitle => 'Download files';

  @override
  String get downloadUnableToQueue =>
      'Unable to add this file to the download queue.';

  @override
  String get downloadFileButton => 'Download';

  @override
  String get downloadAddingToQueue => 'Adding to queue';

  @override
  String downloadSelectionLoading(int percent) {
    return 'Downloading · $percent%';
  }

  @override
  String get downloadManagerUnableToLoad => 'Unable to load downloads.';

  @override
  String get downloadStatusQueued => 'Queued';

  @override
  String get downloadStatusDownloading => 'Downloading';

  @override
  String get downloadStatusPaused => 'Paused';

  @override
  String get downloadStatusCompleted => 'Done';

  @override
  String get downloadStatusFailed => 'Failed';

  @override
  String get downloadNotificationTitle => 'Downloading';

  @override
  String get downloadNotificationChannelName => 'Downloads';

  @override
  String get downloadNotificationChannelDescription =>
      'Download progress for episodes and app updates';

  @override
  String get downloadFailedMessage => 'Download failed';

  @override
  String get downloadWatchButton => 'Watch';

  @override
  String get downloadPauseButton => 'Pause';

  @override
  String get downloadResumeButton => 'Resume';

  @override
  String get downloadDeleteButton => 'Delete';

  @override
  String get downloadCancelButton => 'Cancel';

  @override
  String get downloadDeleteTitle => 'Delete download?';

  @override
  String downloadDeleteMessage(String name) {
    return '“$name” will be removed from this device.';
  }

  @override
  String get animeKindTv => 'TV';

  @override
  String get animeKindMovie => 'Movie';

  @override
  String get animeKindOva => 'OVA';

  @override
  String get animeKindOna => 'ONA';

  @override
  String get animeStatusReleased => 'Released';

  @override
  String get animeStatusOngoing => 'Ongoing';

  @override
  String get animeStatusAnnounced => 'Announced';

  @override
  String animeScoreLabel(String value) {
    return 'Score $value';
  }

  @override
  String animeEpisodeProgress(String aired, String total, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'episodes',
      one: 'episode',
    );
    return '$aired/$total $_temp0';
  }

  @override
  String get animeListLoading => 'Loading anime list';

  @override
  String get animeListLoadError => 'Unable to load anime list.';

  @override
  String get animeListLoadMoreError => 'Couldn’t load more.';

  @override
  String get animeListSearchHint => 'Search anime';

  @override
  String get animeListFilterSortButton => 'Filter & sort';

  @override
  String get animeListSortSectionTitle => 'Sort';

  @override
  String get animeListTypeSectionTitle => 'Type';

  @override
  String get animeListStatusSectionTitle => 'Status';

  @override
  String get animeListSortPopularity => 'Popularity';

  @override
  String get animeListSortScore => 'Score';

  @override
  String get animeListSortAiredOn => 'Release date';

  @override
  String get animeListResetButton => 'Reset';

  @override
  String get animeListEmpty => 'No anime available right now.';

  @override
  String get animeListSearchEmpty => 'No anime found for your search.';

  @override
  String get animeListCriteriaEmpty => 'Nothing matches these filters.';

  @override
  String get animeDetailsLoading => 'Loading anime';

  @override
  String get animeDetailsLoadError => 'Couldn’t load anime.';

  @override
  String get watchSourcesTitle => 'Watch sources';

  @override
  String get watchSourcesLoading => 'Loading sources';

  @override
  String get watchSourcesLoadError => 'Unable to load sources.';

  @override
  String get watchSourcesEmpty => 'No sources found.';

  @override
  String get watchSourcesOnlineSection => 'Online';

  @override
  String get watchSourcesTorrentsSection => 'Torrents';

  @override
  String get watchSourcesOnlineLoading => 'Looking for online sources';

  @override
  String get watchSourcesOnlineLoadError => 'Online sources did not respond.';

  @override
  String get onlineQualityTitle => 'Quality';

  @override
  String get onlineQualityAuto => 'Auto';

  @override
  String onlineQualityHeight(int height) {
    return '${height}p';
  }

  @override
  String watchSourcesOnlineBestQuality(int quality) {
    return 'up to ${quality}p';
  }

  @override
  String get watchSourcesSearchHint => 'Search sources';

  @override
  String get watchSourcesSearchEmpty => 'No matching sources.';

  @override
  String get watchSourcesSortButton => 'Sort';

  @override
  String get watchSourcesSortSheetTitle => 'Sort';

  @override
  String get watchSourcesSortApplyButton => 'Apply';

  @override
  String get watchSourcesSortSeeders => 'Seeders';

  @override
  String get watchSourcesSortPublishedAt => 'Date';

  @override
  String get watchSourcesSortDownloads => 'Downloads';

  @override
  String get watchSourcesSortSize => 'Size';

  @override
  String get watchSourcesSortTitle => 'Title';

  @override
  String get playerSourceTitle => 'Choose file';

  @override
  String get playerSourcePreparing => 'Preparing torrent files';

  @override
  String get playerSourceUnsupported => 'Unsupported source.';

  @override
  String get playerSourceUnableToPrepare => 'Couldn’t open this source.';

  @override
  String get playerSourceEpisodesTitle => 'Choose an episode';

  @override
  String get playerSourceEpisodesPreparing => 'Loading episodes';

  @override
  String playerEpisodeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get playerPreparing => 'Preparing video';

  @override
  String get playerBuffering => 'Buffering';

  @override
  String get playerWaitNoPeers => 'No peers yet';

  @override
  String playerWaitPeers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count peers',
      one: '1 peer',
    );
    return '$_temp0';
  }

  @override
  String playerRuntimeStatsSpeed(String value) {
    return 'Speed $value';
  }

  @override
  String playerRuntimeStatsMemory(String value) {
    return 'Memory $value';
  }

  @override
  String playerRuntimeStatsPeers(String value) {
    return 'Peers $value';
  }

  @override
  String playerRuntimeStatsVideoCodec(String value) {
    return 'Video $value';
  }

  @override
  String playerRuntimeStatsAudioCodec(String value) {
    return 'Audio $value';
  }

  @override
  String get playerUnableToStart => 'Unable to start playback.';

  @override
  String get playerUnableToPrepareFirstFrame => 'Couldn’t display video.';

  @override
  String get playerAudioTracksTitle => 'Audio';

  @override
  String get playerSubtitleTracksTitle => 'Subtitles';

  @override
  String get playerSettingsTitle => 'Settings';

  @override
  String get playerLockScreen => 'Lock screen';

  @override
  String get playerUnlockScreen => 'Unlock';

  @override
  String get playerScreenLocked => 'Screen locked. Tap to unlock';

  @override
  String get playerBrightness => 'Brightness';

  @override
  String get playerDecoderSettingsTitle => 'Decoder';

  @override
  String get playerDecoderSettingsDescription =>
      'Only change if video stutters or glitches.';

  @override
  String get playerDecoderAutoSafe => 'Auto (recommended)';

  @override
  String get playerDecoderMediacodec => 'MediaCodec';

  @override
  String get playerDecoderMediacodecCopy => 'MediaCodec (copy-back)';

  @override
  String get playerDecoderSoftwareOnly => 'Software only';

  @override
  String get playerPlaybackSectionTitle => 'Playback';

  @override
  String get playerPlaybackSpeedTitle => 'Playback speed';

  @override
  String get playerVideoFitTitle => 'Video fit';

  @override
  String playerPlaybackRate(double rate) {
    final intl.NumberFormat rateNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String rateString = rateNumberFormat.format(rate);

    return '$rateString×';
  }

  @override
  String get playerSubtitleAppearanceTitle => 'Subtitle appearance';

  @override
  String get playerSubtitleLibassLabel => 'Improved ASS/SSA rendering';

  @override
  String get playerSubtitleLibassDescription =>
      'Preserves ASS/SSA fonts, styles, and positioned signs.';

  @override
  String get playerSubtitleSizeLabel => 'Size';

  @override
  String get playerSubtitleColorLabel => 'Text color';

  @override
  String get playerSubtitleBackgroundLabel => 'Background';

  @override
  String get playerSubtitlePositionLabel => 'Position';

  @override
  String get playerSubtitleResetAction => 'Reset';

  @override
  String get playerSubtitleSizeSample => 'Aa';

  @override
  String get playerSubtitleSizeSmaller => 'Smaller';

  @override
  String get playerSubtitleSizeNormal => 'Normal';

  @override
  String get playerSubtitleSizeLarger => 'Larger';

  @override
  String get playerSubtitleSizeLargest => 'Largest';

  @override
  String get playerSubtitleOverrideHint =>
      'A custom color, background, or position replaces the release’s styling: styled signs become plain text.';

  @override
  String get playerAdvancedTitle => 'Advanced';

  @override
  String playerAdvancedSummary(String decoder, String ass) {
    return 'Decoder: $decoder · ASS rendering: $ass';
  }

  @override
  String get playerSettingOn => 'on';

  @override
  String get playerSettingOff => 'off';

  @override
  String get playerDecoderAutoShort => 'Auto';

  @override
  String get playerRestartHint =>
      'Changing the decoder or ASS rendering restarts playback at the current position.';

  @override
  String get playerDecoderRestartHint =>
      'Changing the decoder restarts the video at the current position.';

  @override
  String get playerSubtitleColorWhite => 'White';

  @override
  String get playerSubtitleColorYellow => 'Yellow';

  @override
  String get playerSubtitleColorCyan => 'Cyan';

  @override
  String get playerSubtitleBackgroundNone => 'Off';

  @override
  String get playerSubtitleBackgroundTranslucent => 'Translucent';

  @override
  String get playerSubtitleBackgroundSolid => 'Solid';

  @override
  String get playerSubtitlePositionLow => 'Lower';

  @override
  String get playerSubtitlePositionStandard => 'Standard';

  @override
  String get playerSubtitlePositionHigh => 'Higher';

  @override
  String get playerTrackAuto => 'Auto';

  @override
  String get playerTrackOff => 'Off';

  @override
  String get playerTrackUnnamed => 'Track';

  @override
  String get playerTrackLanguageEnglish => 'English';

  @override
  String get playerTrackLanguageJapanese => 'Japanese';

  @override
  String get playerTrackLanguageRussian => 'Russian';

  @override
  String get playerTracksUnavailable => 'Not available';

  @override
  String get invalidRouteArgumentsMessage => 'Couldn’t open this screen.';

  @override
  String get playerPlayButton => 'Play';

  @override
  String get playerPauseButton => 'Pause';

  @override
  String get savedTorrentsAddButton => 'Add torrent';

  @override
  String get savedTorrentsAddTitle => 'Add torrent';

  @override
  String get savedTorrentsMagnetLabel => 'Magnet link';

  @override
  String get savedTorrentsPasteTooltip => 'Paste from clipboard';

  @override
  String get savedTorrentsNameLabel => 'Name';

  @override
  String get savedTorrentsInvalidMagnet =>
      'Not a magnet link with a torrent hash (xt=urn:btih:…).';

  @override
  String get savedTorrentsSaveButton => 'Save';

  @override
  String savedTorrentsDuplicate(String title) {
    return 'Already added as “$title”';
  }

  @override
  String get commonMoreActions => 'More actions';

  @override
  String get savedTorrentsRename => 'Rename';

  @override
  String get savedTorrentsCopyLink => 'Copy link';

  @override
  String get savedTorrentsLinkCopied => 'Link copied';

  @override
  String get savedTorrentsDelete => 'Delete';

  @override
  String savedTorrentsAddedOn(String date) {
    return 'Added $date';
  }

  @override
  String savedTorrentsOpenedOn(String date) {
    return 'Opened $date';
  }

  @override
  String get downloadStorageClearCache => 'Clear';

  @override
  String get downloadsLoading => 'Loading downloaded files';

  @override
  String get downloadDeleteFailed =>
      'Couldn’t delete the files. One may still be open.';

  @override
  String playerResumedFrom(String position) {
    return 'Resumed from $position';
  }

  @override
  String get playerStartOver => 'Start over';

  @override
  String playerResumingFrom(String position) {
    return 'Picking up at $position';
  }

  @override
  String get playerStartingOver => 'Starting from the beginning';

  @override
  String get playerStartedOver => 'Playing from the beginning';

  @override
  String playerResumeFromAction(String position) {
    return 'From $position';
  }

  @override
  String get playerPlayNext => 'Next episode';

  @override
  String get playerPartOpening => 'Opening';

  @override
  String get playerPartEnding => 'Ending';

  @override
  String get playerPartRecap => 'Recap';

  @override
  String get playerSkipOpening => 'Skip opening';

  @override
  String get playerSkipRecap => 'Skip recap';

  @override
  String playerSkipForward(int seconds) {
    return '+$seconds s';
  }

  @override
  String playerSkipForwardTooltip(int seconds) {
    return 'Skip $seconds seconds';
  }

  @override
  String get watchProgressWatched => 'Watched';

  @override
  String watchProgressStoppedAt(String position, String duration) {
    return 'Stopped at $position of $duration';
  }

  @override
  String get watchProgressContinueButton => 'Continue';

  @override
  String get watchProgressPlayNextButton => 'Play next';

  @override
  String get watchProgressWatchButton => 'Watch';

  @override
  String watchProgressLastFile(String fileName) {
    return 'Last watched: $fileName';
  }

  @override
  String get continueWatchingTitle => 'Continue watching';

  @override
  String get continueWatchingRemove => 'Remove from list';

  @override
  String get animeListHeadingPopularity => 'Popular';

  @override
  String get animeListHeadingScore => 'Top rated';

  @override
  String get animeListHeadingAiredOn => 'Latest';

  @override
  String get recentlyWatchedTitle => 'Recently watched';

  @override
  String get watchSourceUsedBadge => 'Watched';

  @override
  String get playerEpisodesTitle => 'Episodes';

  @override
  String get playerNowPlaying => 'Now playing';

  @override
  String get playerDetailedStats => 'Technical details';

  @override
  String get playerDetailedStatsHint =>
      'Peers, decoder and codecs over the video';

  @override
  String get playerBack => 'Back';

  @override
  String playerEpisodeNumber(int number) {
    return 'Episode $number';
  }

  @override
  String playerEpisodePosition(int position, int total) {
    return '$position of $total';
  }

  @override
  String playerEpisodeOfTotal(int total) {
    return 'of $total';
  }

  @override
  String playerTimeLeft(String time) {
    return '$time left';
  }

  @override
  String get playerMute => 'Mute';

  @override
  String get playerUnmute => 'Unmute';

  @override
  String get playerAudioAndSubtitles => 'Audio & subtitles';

  @override
  String get playerPictureInPicture => 'Picture in picture';

  @override
  String get playerPictureInPictureOff =>
      'Picture in picture is turned off for Iris in system settings.';

  @override
  String get playerPictureInPictureFailed => 'Couldn’t open the mini player.';

  @override
  String get playerRestoreFromPictureInPicture => 'Restore player';

  @override
  String get playerClosePictureInPicture => 'Close mini player';

  @override
  String get playerEnterFullscreen => 'Full screen';

  @override
  String get playerExitFullscreen => 'Exit full screen';

  @override
  String get playerCloseEpisodes => 'Close episodes';

  @override
  String get playerZoomFill => 'Fill screen';

  @override
  String get playerZoomFit => 'Fit to screen';

  @override
  String playerRate(String value) {
    return '$value/s';
  }

  @override
  String get byteUnitB => 'B';

  @override
  String get byteUnitKB => 'KB';

  @override
  String get byteUnitMB => 'MB';

  @override
  String get byteUnitGB => 'GB';

  @override
  String playerTimePosition(String position, String duration) {
    return '$position of $duration';
  }

  @override
  String get playerSeekBarLabel => 'Playback position';

  @override
  String get animeDetailsChooseSourceButton => 'Choose source';

  @override
  String animeEpisodeCount(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'episodes',
      one: 'episode',
    );
    return '$value $_temp0';
  }

  @override
  String watchSourceSeeders(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'seeders',
      one: 'seeder',
    );
    return '$value $_temp0';
  }

  @override
  String watchSourceDownloads(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'downloads',
      one: 'download',
    );
    return '$value $_temp0';
  }

  @override
  String get searchClearTooltip => 'Clear';

  @override
  String get searchCancelButton => 'Cancel';

  @override
  String get animeDetailsFactKind => 'Type';

  @override
  String get animeDetailsFactStatus => 'Status';

  @override
  String get animeDetailsFactEpisodes => 'Episodes';

  @override
  String get animeDetailsFactScore => 'Score';

  @override
  String get animeDetailsFactAired => 'Aired';

  @override
  String animeDetailsEpisodesAired(String aired, String total) {
    return '$aired of $total';
  }

  @override
  String get animeDetailsDescriptionTitle => 'Synopsis';

  @override
  String get animeDetailsShowCover => 'Show original cover';

  @override
  String get animeDetailsShowHalftone => 'Show halftone';

  @override
  String get watchSourcesColumnRelease => 'Release';

  @override
  String get watchSourcesColumnSize => 'Size';

  @override
  String get watchSourcesColumnSeeders => 'Seeders';

  @override
  String get watchSourcesColumnDownloads => 'Downloads';

  @override
  String get watchSourcesColumnDate => 'Date';

  @override
  String commonShowMore(int count) {
    return '$count more';
  }

  @override
  String get commonShowLess => 'Show less';

  @override
  String get animeKindSpecial => 'Special';

  @override
  String get animeKindTvSpecial => 'TV special';

  @override
  String get animeDetailsRelatedTitle => 'Related';

  @override
  String get animeRelationPrequel => 'Prequel';

  @override
  String get animeRelationSequel => 'Sequel';

  @override
  String get animeRelationParentStory => 'Parent story';

  @override
  String get animeRelationFullStory => 'Full story';

  @override
  String get animeRelationSideStory => 'Side story';

  @override
  String get animeRelationAlternativeSetting => 'Alternative setting';

  @override
  String get animeRelationAlternativeVersion => 'Alternative version';

  @override
  String get animeRelationSpinOff => 'Spin-off';

  @override
  String get animeRelationSummary => 'Summary';

  @override
  String get animeRelationCharacter => 'Shared characters';

  @override
  String get animeRelationOther => 'Other';

  @override
  String get navigationProfile => 'Profile';

  @override
  String get profileSignInTitle => 'Shikimori account';

  @override
  String get profileSignInMessage =>
      'Sync your lists, episode progress, and friends from Shikimori';

  @override
  String get profileSignInUnavailable => 'Sign-in is not set up in this build';

  @override
  String get profileSigningIn => 'Waiting for Shikimori';

  @override
  String get profileSignInNetworkError => 'No response from Shikimori.';

  @override
  String get profileSignInRejected => 'Couldn’t sign in.';

  @override
  String get profileSessionExpired => 'Session expired. Sign in again.';

  @override
  String get userRateTitle => 'My list';

  @override
  String get userRateAdd => 'Add to list';

  @override
  String get userRateRemove => 'Remove from list';

  @override
  String get userRateStatusPlanned => 'Planned';

  @override
  String get userRateStatusWatching => 'Watching';

  @override
  String get userRateStatusRewatching => 'Rewatching';

  @override
  String get userRateStatusCompleted => 'Completed';

  @override
  String get userRateStatusOnHold => 'On hold';

  @override
  String get userRateStatusDropped => 'Dropped';

  @override
  String get userRateEpisodeLess => 'One episode less';

  @override
  String get userRateEpisodeMore => 'One more episode';

  @override
  String userRateEpisodesWatched(String count) {
    return 'Episodes watched: $count';
  }

  @override
  String get userRateLoadError => 'Couldn’t load list.';

  @override
  String get userRateSaveError => 'Couldn’t save to Shikimori.';

  @override
  String userRateScore(int score) {
    return 'Score: $score';
  }

  @override
  String get userRateRate => 'Rate';

  @override
  String get userRateNoScore => 'No score';

  @override
  String get animeListHideCompleted => 'Not completed';

  @override
  String get animeListGenresSectionTitle => 'Genres';

  @override
  String get animeListSeasonSectionTitle => 'Season';

  @override
  String animeSeasonWinter(String year) {
    return 'Winter $year';
  }

  @override
  String animeSeasonSpring(String year) {
    return 'Spring $year';
  }

  @override
  String animeSeasonSummer(String year) {
    return 'Summer $year';
  }

  @override
  String animeSeasonFall(String year) {
    return 'Fall $year';
  }

  @override
  String animeListDecade(String decade) {
    return '${decade}s';
  }

  @override
  String get animeListBefore2000 => 'Before 2000';

  @override
  String get animeListRatingSectionTitle => 'Age rating';

  @override
  String get animeListDurationSectionTitle => 'Episode length';

  @override
  String get animeDurationShort => 'Under 10 min';

  @override
  String get animeDurationStandard => 'Under 30 min';

  @override
  String get animeDurationLong => 'Over 30 min';

  @override
  String animeNextEpisodeToday(String time) {
    return 'today at $time';
  }

  @override
  String animeNextEpisodeTomorrow(String time) {
    return 'tomorrow at $time';
  }

  @override
  String animeNextEpisodeInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return 'in $_temp0';
  }

  @override
  String animeNextEpisode(int episode, String when) {
    return 'Episode $episode $when';
  }

  @override
  String profileListEmpty(String status) {
    return 'Nothing in “$status”';
  }

  @override
  String get profileListLoadError => 'Couldn’t load list.';

  @override
  String get profileListLoading => 'Loading list';

  @override
  String get profileFriendsTab => 'Friends';

  @override
  String get profileFriendsEmpty => 'No friends on Shikimori yet.';

  @override
  String get profileFriendsLoadError => 'Couldn’t load friends.';

  @override
  String get profileFriendsLoading => 'Loading friends';

  @override
  String get animeDetailsFriendsTitle => 'Friends';

  @override
  String get appUpdateDownload => 'Download';

  @override
  String get appUpdateLater => 'Later';

  @override
  String get appUpdateOpenFailed => 'Couldn’t open the download link.';

  @override
  String get appUpdateNotificationTitle => 'Iris update';

  @override
  String appUpdateNoticeAvailable(String version) {
    return 'Version $version available';
  }

  @override
  String get appUpdateNoticeDownloading => 'Downloading';

  @override
  String appUpdateNoticeDownloadingVersion(String version) {
    return 'Downloading $version';
  }

  @override
  String get appUpdateNoticeReady => 'Update ready';

  @override
  String get appUpdateNoticeRestartReady => 'Ready to restart';

  @override
  String get appUpdateNoticePermissionNeeded => 'Permission needed';

  @override
  String get appUpdateNoticeInstallFailed => 'Couldn’t install';

  @override
  String get appUpdateNoticeFailed => 'Download failed';

  @override
  String get appUpdateNoticeVerifying => 'Verifying file';

  @override
  String get appUpdateNoticeInstalling => 'Opening installer';

  @override
  String get appUpdateNoticeRestarting => 'Restarting Iris';

  @override
  String get appUpdateWhatsNew => 'What’s new';

  @override
  String get appUpdateNoNotes => 'No release notes.';

  @override
  String get appUpdateCancelDownload => 'Cancel';

  @override
  String get appUpdateInstall => 'Install';

  @override
  String get appUpdateRetryInstall => 'Retry install';

  @override
  String get appUpdateRestart => 'Restart';

  @override
  String get appUpdateRestartAndUpdate => 'Restart and update';

  @override
  String get appUpdateDownloading => 'Downloading';

  @override
  String get appUpdateRetry => 'Retry';

  @override
  String get appUpdateDownloadAgain => 'Download again';

  @override
  String appUpdateProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get appUpdateFailureNetwork =>
      'Couldn’t download the update. Network error.';

  @override
  String get appUpdateFailureInvalidFile => 'File damaged';

  @override
  String get appUpdateFailureStorage => 'Not enough storage for the update.';

  @override
  String get appUpdateFailureInstall => 'Couldn’t open the installer.';

  @override
  String get appUpdateFailurePermission =>
      'Allow Iris to install apps in Android settings.';

  @override
  String get charactersTitle => 'Characters';

  @override
  String charactersAll(int count) {
    return 'All $count';
  }

  @override
  String get charactersMainTitle => 'Main';

  @override
  String get charactersSupportingTitle => 'Supporting';

  @override
  String get charactersLoading => 'Loading characters';

  @override
  String get charactersLoadError => 'Unable to load the characters.';

  @override
  String get charactersEmpty => 'No characters are listed.';

  @override
  String get characterLoading => 'Loading character';

  @override
  String get characterLoadError => 'Unable to load the character.';

  @override
  String get characterDescriptionTitle => 'About';

  @override
  String get characterAnimeTitle => 'Anime';

  @override
  String get characterFactJapanese => 'Japanese';

  @override
  String get characterFactAltNames => 'Other names';

  @override
  String get characterRoleMain => 'Main role';

  @override
  String get characterRoleSupporting => 'Supporting role';

  @override
  String get animeDetailsFactNextEpisode => 'Next';

  @override
  String get animeDetailsFactStudio => 'Studio';

  @override
  String get animeDetailsFactGenres => 'Genres';

  @override
  String get animeDetailsFactRating => 'Rated';

  @override
  String playerMarked(int episode) {
    return 'Episode $episode marked';
  }

  @override
  String playerMarkOffer(int episode) {
    return 'Mark episode $episode on Shikimori?';
  }

  @override
  String get playerMarkAction => 'Mark';

  @override
  String playerMarkFailed(int episode) {
    return 'Could not mark episode $episode';
  }

  @override
  String get playerUnmarkFailed => 'Could not undo';

  @override
  String get playerRestoreFailed => 'Could not restore';

  @override
  String playerMarkUnset(int episode) {
    return 'Episode $episode not marked';
  }

  @override
  String playerMarkWaiting(int episode) {
    return 'Episode $episode waiting to sync';
  }

  @override
  String playerMarkSyncFailed(int episode) {
    return 'Episode $episode · sync failed';
  }

  @override
  String get playerMarkConflict => 'List entry changed elsewhere';

  @override
  String get playerMarkSaving => 'Marking';

  @override
  String get playerUnmarkSaving => 'Undoing';

  @override
  String get playerRestoreSaving => 'Restoring mark';

  @override
  String get playerMarkShortMarked => 'Marked';

  @override
  String get playerMarkShortUnset => 'Not marked';

  @override
  String get playerMarkShortFailed => 'Could not mark';

  @override
  String get playerMarkShortWaiting => 'Waiting to sync';

  @override
  String get playerMarkShortSyncFailed => 'Sync failed';

  @override
  String get playerMarkShortConflict => 'Entry changed';

  @override
  String get playerMarkShortRestoreSaving => 'Restoring';

  @override
  String get playerMarkRestore => 'Restore';

  @override
  String get playerMarkExpand => 'Show mark actions';

  @override
  String get playerMarkCollapse => 'Hide mark actions';

  @override
  String get playerMarkDismiss => 'Close';

  @override
  String playerMarkPreviously(String status) {
    return 'Previously: $status';
  }

  @override
  String playerMarkNextPending(int current, int total) {
    return 'Next mark: $current of $total';
  }

  @override
  String get profileSigningInHint =>
      'Complete sign-in in your browser. Returning early cancels it.';

  @override
  String get profileSignInPortBusy => 'Port 43821 is in use by another app.';

  @override
  String get profileListTab => 'List';

  @override
  String get profileListEmptyHint => 'Set a status from an anime’s page.';

  @override
  String profileListProgress(int watched, int total) {
    return '$watched of $total ep.';
  }

  @override
  String profileListWatched(int watched) {
    return '$watched ep.';
  }

  @override
  String get commonBrowseCatalog => 'Browse the catalog';

  @override
  String get savedTorrentsAddConfirm => 'Add';

  @override
  String get savedTorrentsAdding => 'Adding torrent';

  @override
  String get savedTorrentsSaveFailed => 'Couldn’t save the torrent.';

  @override
  String get savedTorrentsDeleted => 'Torrent deleted';

  @override
  String savedTorrentsEpisodeWatched(int number) {
    return 'Episode $number watched';
  }

  @override
  String savedTorrentsFileWatched(String fileName) {
    return 'Watched: $fileName';
  }

  @override
  String get commonUndo => 'Undo';

  @override
  String get userRateLoading => 'Loading list';

  @override
  String get downloadNoPeers => 'no peers yet';

  @override
  String get downloadTimeLeftUnderMinute => '< 1 min left';

  @override
  String downloadTimeLeftMinutes(int minutes) {
    return '~$minutes min left';
  }

  @override
  String downloadTimeLeftHours(int hours, int minutes) {
    return '~$hours h $minutes min left';
  }

  @override
  String get downloadFailedNoSpace => 'Out of storage space';

  @override
  String get downloadFailedNoAccess => 'Can’t write to downloads folder';

  @override
  String get downloadFailedFileMissing => 'File not found';

  @override
  String get downloadFailedCouldNotStart => 'Couldn’t start download';

  @override
  String get downloadSelectionEpisodeTitle => 'Download episodes';

  @override
  String get downloadFailedConnectionLost => 'Connection to server lost';

  @override
  String get downloadFailedNotDownloadable => 'Streaming only';

  @override
  String downloadDeleteProgressLost(String size) {
    return '$size already downloaded will be deleted.';
  }

  @override
  String downloadAnnounceCompleted(String name) {
    return 'Downloaded: $name';
  }

  @override
  String downloadAnnounceFailed(String name) {
    return 'Download failed: $name';
  }

  @override
  String get watchSourcesMineSection => 'Mine';

  @override
  String get watchSourcesAddOwnTorrent => 'Add your own torrent';

  @override
  String savedTorrentsAddWithShortcut(String shortcut) {
    return 'Add torrent ($shortcut)';
  }

  @override
  String get savedTorrentsOr => 'or';

  @override
  String get savedTorrentsChooseFile => 'Choose a .torrent file';

  @override
  String get savedTorrentsNotTorrentFile => 'This file is not a torrent.';

  @override
  String get savedTorrentsFileTooLarge =>
      'This file is too large to be a torrent.';

  @override
  String get savedTorrentsFileReadFailed => 'Couldn’t read the file.';

  @override
  String get savedTorrentsFromFile => 'from a file';

  @override
  String get savedTorrentsFromLink => 'from a link';

  @override
  String savedTorrentsFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String get savedTorrentsClearDraft => 'Remove';

  @override
  String downloadTitleReady(int ready, int total) {
    return '$ready of $total ready';
  }

  @override
  String get downloadTitleEmpty => 'No episodes remain on this device.';

  @override
  String downloadEpisodeLabel(String number) {
    return 'Episode $number';
  }

  @override
  String get downloadOpenAnime => 'Open anime';

  @override
  String get downloadStatusDetails => 'Download status';

  @override
  String downloadTitleEpisodeCount(int ready, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'episodes',
      one: 'episode',
    );
    return '$ready of $total $_temp0';
  }

  @override
  String get downloadDeleteAll => 'Delete all episodes';

  @override
  String get animeListDemographicsSectionTitle => 'Audience';

  @override
  String get animeListThemesSectionTitle => 'Themes';

  @override
  String get animeListCollapse => 'Show less';

  @override
  String get animeListShowResults => 'Show results';

  @override
  String animeListShowCount(String count) {
    return 'Show $count';
  }

  @override
  String get searchRecentEmpty => 'No recent searches yet.';

  @override
  String get searchRecentClear => 'Clear history';

  @override
  String searchRecentRemove(String query) {
    return 'Remove “$query”';
  }

  @override
  String animeListRemoveFilter(String filter) {
    return 'Remove “$filter” filter';
  }

  @override
  String get animeListFiltersTitle => 'Filters';

  @override
  String get animeListResetFilters => 'Reset filters';

  @override
  String animeListShowMore(int count) {
    return 'More ($count)';
  }

  @override
  String get downloadSelect => 'Select';

  @override
  String downloadDeleteSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count',
      zero: 'Delete',
    );
    return '$_temp0';
  }

  @override
  String downloadDeleteSelectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count downloads?',
      one: 'Delete $count download?',
    );
    return '$_temp0';
  }

  @override
  String downloadDeleteSpace(String size) {
    return 'About $size will be freed.';
  }

  @override
  String get downloadDeleteUnfinished =>
      'Unfinished downloads will be canceled.';

  @override
  String get downloadDeleting => 'Deleting';

  @override
  String downloadDeleteSelectionFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Couldn’t delete $count downloads.',
      one: 'Couldn’t delete $count download.',
    );
    return '$_temp0';
  }

  @override
  String get downloadSelectEpisodes => 'Select episodes';

  @override
  String get downloadSelectFiles => 'Select files';

  @override
  String get downloadSelectAll => 'Select all';

  @override
  String get downloadDeselectAll => 'Deselect all';

  @override
  String playerSourceSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String playerSourceNextEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Next $count episodes',
      one: 'Next episode',
    );
    return '$_temp0';
  }

  @override
  String playerSourceNextFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Next $count files',
      one: 'Next file',
    );
    return '$_temp0';
  }

  @override
  String get playerSourceAllUnwatched => 'Unwatched';

  @override
  String get playerSourceDownloadQuality => 'Download quality';

  @override
  String get playerSourceDownloaded => 'Downloaded';

  @override
  String playerSourceDownloadedCount(int count) {
    return '$count downloaded';
  }

  @override
  String get playerSourceQueueFailed => 'Couldn’t add to the queue.';

  @override
  String get playerSourceUnwatched => 'Unwatched';

  @override
  String playerSourceEpisodeLabel(String number) {
    return 'Episode $number';
  }

  @override
  String playerSourceFileLabel(String number) {
    return 'File $number';
  }

  @override
  String get playerEpisodeFiller => 'Filler';

  @override
  String get playerEpisodeRecap => 'Recap';

  @override
  String downloadSelectedEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count episodes',
      one: 'Download $count episode',
      zero: 'Download',
    );
    return '$_temp0';
  }

  @override
  String downloadSelectedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Download $count files',
      one: 'Download $count file',
      zero: 'Download',
    );
    return '$_temp0';
  }

  @override
  String get downloadQueueTitle => 'Download queue';

  @override
  String downloadQueueCount(int count) {
    return 'Queue · $count';
  }

  @override
  String get downloadNext => 'Move to front';

  @override
  String get downloadMore => 'Download more';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsShortcutTooltip => 'Settings · Ctrl+,';

  @override
  String get settingsSectionAccounts => 'Accounts';

  @override
  String get settingsSectionPlayback => 'Playback';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsAccountSignedOut => 'Not connected';

  @override
  String get settingsCheckingSession => 'Checking session';

  @override
  String get settingsSigningIn => 'Signing in';

  @override
  String get settingsAnimejoySignedIn => 'Connected';

  @override
  String get settingsAnimejoyUnverified => 'Couldn’t verify session';

  @override
  String get settingsAnimejoyExpired => 'Session expired. Sign in again.';

  @override
  String get settingsAnimejoyVerify => 'Verify';

  @override
  String get settingsAnimejoySignInTitle => 'Sign in to AnimeJoy';

  @override
  String get settingsAnimejoyLoginLabel => 'Username';

  @override
  String get settingsAnimejoyPasswordLabel => 'Password';

  @override
  String get settingsAnimejoyShowPassword => 'Show password';

  @override
  String get settingsAnimejoyHidePassword => 'Hide password';

  @override
  String get settingsAnimejoyLoginRequired => 'Enter username';

  @override
  String get settingsAnimejoyPasswordRequired => 'Enter password';

  @override
  String get settingsAnimejoyErrorInvalidCredentials =>
      'Wrong username or password';

  @override
  String get settingsAnimejoyErrorNetwork => 'No response from AnimeJoy.';

  @override
  String get settingsAnimejoyErrorUnavailable => 'Sign-in unavailable';

  @override
  String get settingsDefaultAudioLabel => 'Audio';

  @override
  String get settingsDefaultSubtitlesLabel => 'Subtitles';

  @override
  String get settingsTrackAuto => 'Auto';

  @override
  String get settingsAudioJapanese => 'Japanese';

  @override
  String get settingsAudioRussian => 'Russian';

  @override
  String get settingsAudioEnglish => 'English';

  @override
  String get settingsSubtitlesRussian => 'Russian';

  @override
  String get settingsSubtitlesEnglish => 'English';

  @override
  String get settingsSubtitlesOff => 'Off';

  @override
  String get settingsThemeLabel => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageRussian => 'Русский';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsAnimeTitleLanguageLabel => 'Anime titles';

  @override
  String get settingsAnimeTitleLanguageAuto => 'Auto';

  @override
  String get settingsAnimeTitleLanguageRussian => 'Russian';

  @override
  String get settingsAnimeTitleLanguageRomaji => 'Romaji';

  @override
  String get settingsAnimeTitleLanguageEnglish => 'English';

  @override
  String get settingsEpisodeListLayoutLabel => 'Episodes view';

  @override
  String get settingsEpisodeListLayoutAuto => 'Auto';

  @override
  String get settingsEpisodeListLayoutList => 'List';

  @override
  String get settingsEpisodeListLayoutGrid => 'Grid';

  @override
  String get settingsAppVersion => 'Version';

  @override
  String get settingsAppVersionUnknown => 'Unknown';

  @override
  String get settingsCheckUpdates => 'Check';

  @override
  String get settingsUpdateChecking => 'Checking';

  @override
  String get settingsUpdateUpToDate => 'Up to date';

  @override
  String get settingsUpdateCheckFailed => 'Couldn’t check';

  @override
  String get settingsUpdateOpen => 'Update';

  @override
  String get settingsUpdateOpenDetails => 'Details';

  @override
  String get settingsUpdateAvailableHint => 'Update available';

  @override
  String get animeDetailsBackToDescriptionButton => 'Back to details';

  @override
  String get animeDetailsBackToSourcesButton => 'Back to sources';
}
