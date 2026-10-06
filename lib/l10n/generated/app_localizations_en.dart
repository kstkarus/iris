// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Iris';

  @override
  String get commonRetry => 'Try Again';

  @override
  String get navigationCatalog => 'Catalog';

  @override
  String get navigationDownloads => 'Downloads';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsOpenButton => 'Download';

  @override
  String get downloadsEmpty => 'Downloaded episodes will appear here.';

  @override
  String get downloadSelectionTitle => 'Download a file';

  @override
  String get downloadSelectionPreparing => 'Loading torrent file list...';

  @override
  String get downloadSelectionUnsupported =>
      'This source has no supported video files.';

  @override
  String get downloadSelectionUnableToPrepare =>
      'Unable to load files from this source.';

  @override
  String get downloadUnableToQueue =>
      'Unable to add this file to the download queue.';

  @override
  String get downloadFileButton => 'Download';

  @override
  String get downloadAddingToQueue => 'Adding to queue...';

  @override
  String get downloadManagerUnableToLoad => 'Unable to load downloads.';

  @override
  String get downloadStorageTitle => 'App storage';

  @override
  String get downloadStorageTotal => 'Total used by app';

  @override
  String get downloadStorageContent => 'Offline content';

  @override
  String get downloadStorageCache => 'Cache';

  @override
  String get downloadStatusQueued => 'Queued';

  @override
  String get downloadStatusDownloading => 'Downloading';

  @override
  String get downloadStatusPaused => 'Paused';

  @override
  String get downloadStatusCompleted => 'Downloaded';

  @override
  String get downloadStatusFailed => 'Failed';

  @override
  String downloadPeers(int count) {
    return 'Peers: $count';
  }

  @override
  String get downloadFailedMessage => 'The download stopped with an error.';

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
    return 'The file “$name” will be removed from the device.';
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
  String get animeListLoading => 'Loading anime list...';

  @override
  String get animeListLoadError => 'Unable to load anime list.';

  @override
  String get animeListLoadMoreError => 'Unable to load more anime.';

  @override
  String get animeListSearchHint => 'Search anime';

  @override
  String get animeListFilterSortButton => 'Filter & Sort';

  @override
  String get animeListFilterSortTitle => 'Filter & Sort';

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
  String get animeListSortAiredOn => 'Aired On';

  @override
  String get animeListApplyButton => 'Apply';

  @override
  String get animeListResetButton => 'Reset';

  @override
  String get animeListEmpty => 'No anime available right now.';

  @override
  String get animeListSearchEmpty => 'No anime found for your search.';

  @override
  String get animeListCriteriaEmpty => 'Nothing found for selected criteria.';

  @override
  String get animeDetailsLoading => 'Loading anime details...';

  @override
  String get animeDetailsLoadError => 'Unable to load anime details.';

  @override
  String get watchSourcesTitle => 'Watch sources';

  @override
  String get watchSourcesOpenButton => 'Watch';

  @override
  String get watchSourcesLoading => 'Loading sources...';

  @override
  String get watchSourcesLoadError => 'Unable to load sources.';

  @override
  String get watchSourcesEmpty => 'No sources found.';

  @override
  String get watchSourcesSearchHint => 'Search sources';

  @override
  String get watchSourcesSearchEmpty => 'No sources match your search.';

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
  String get watchSourcesSortTitle => 'Title';

  @override
  String get watchSourcesPageLinkLabel => 'Page Link';

  @override
  String get watchSourcesTorrentLinkLabel => 'Torrent Link';

  @override
  String get watchSourcesMagnetLinkLabel => 'Magnet Link';

  @override
  String get playerTitle => 'Player';

  @override
  String get playerOpenButton => 'Play';

  @override
  String get playerSourceTitle => 'Choose File';

  @override
  String get playerSourcePreparing => 'Preparing torrent files...';

  @override
  String get playerSourceUnsupported =>
      'This source is not suitable for playback.';

  @override
  String get playerSourceUnableToPrepare => 'Unable to prepare this source.';

  @override
  String get playerPreparing => 'Preparing video...';

  @override
  String get playerWaitingMetadata => 'Looking for torrent metadata...';

  @override
  String get playerBuffering => 'Buffering...';

  @override
  String get playerPreparingMoreBuffer => 'Collecting more buffered data...';

  @override
  String playerStreamPreparationProgress(int percent) {
    return '$percent% ready for playback';
  }

  @override
  String playerStreamPreparationSpeed(String value) {
    return 'Current speed: $value';
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
  String get playerUnableToPrepareFirstFrame =>
      'The stream is open, but the player could not prepare the first frame.';

  @override
  String get playerUnableToBufferForStart =>
      'Unable to prepare enough buffered data to start playback.';

  @override
  String get playerNoPlayableVideo => 'No playable video found.';

  @override
  String get playerTracksTitle => 'Playback Tracks';

  @override
  String get playerAudioTracksTitle => 'Audio';

  @override
  String get playerSubtitleTracksTitle => 'Subtitles';

  @override
  String get playerSettingsTitle => 'Player Settings';

  @override
  String get playerDecoderSettingsTitle => 'Decoder';

  @override
  String get playerDecoderSettingsDescription =>
      'Change this only if video stutters or shows green frames on your device. The current decoder is visible in the player overlay stats.';

  @override
  String get playerDecoderAutoSafe => 'Auto (recommended)';

  @override
  String get playerDecoderMediacodec => 'MediaCodec';

  @override
  String get playerDecoderMediacodecCopy => 'MediaCodec (zero-copy)';

  @override
  String get playerDecoderSoftwareOnly => 'Software only';

  @override
  String get playerSubtitleAppearanceTitle => 'Subtitle Appearance';

  @override
  String get playerSubtitleVisibilityLabel => 'Show subtitles';

  @override
  String get playerSubtitleLibassLabel => 'Improved ASS/SSA rendering';

  @override
  String get playerSubtitleLibassDescription =>
      'Uses native subtitle rendering for better compatibility with anime releases.';

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
  String get playerTracksUnavailable => 'Not available';

  @override
  String get invalidRouteArgumentsMessage =>
      'This screen was opened with invalid navigation data.';

  @override
  String get playerPlayButton => 'Play';

  @override
  String get playerPauseButton => 'Pause';

  @override
  String get navigationSavedTorrents => 'Torrents';

  @override
  String get savedTorrentsTitle => 'Torrents';

  @override
  String get savedTorrentsAddButton => 'Add magnet';

  @override
  String get savedTorrentsEmptyTitle => 'No saved torrents yet';

  @override
  String get savedTorrentsEmptyMessage =>
      'Paste a magnet link to stream or download it. Saved links stay here for later.';

  @override
  String get savedTorrentsAddTitle => 'Add magnet link';

  @override
  String get savedTorrentsMagnetLabel => 'Magnet link';

  @override
  String get savedTorrentsPasteTooltip => 'Paste from clipboard';

  @override
  String get savedTorrentsNameLabel => 'Name';

  @override
  String get savedTorrentsNameHelper => 'Taken from the link if left empty';

  @override
  String get savedTorrentsInvalidMagnet =>
      'Not a magnet link with a torrent hash (xt=urn:btih:…).';

  @override
  String get savedTorrentsSaveButton => 'Save';

  @override
  String get savedTorrentsAdded => 'Torrent saved';

  @override
  String savedTorrentsDuplicate(String title) {
    return 'Already saved as “$title”';
  }

  @override
  String get savedTorrentsMoreTooltip => 'More actions';

  @override
  String get savedTorrentsRename => 'Rename';

  @override
  String get savedTorrentsCopyLink => 'Copy link';

  @override
  String get savedTorrentsLinkCopied => 'Link copied';

  @override
  String get savedTorrentsDelete => 'Delete';

  @override
  String savedTorrentsDeleteTitle(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get savedTorrentsDeleteMessage =>
      'Only the saved link is removed. Downloaded files stay in Downloads.';

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
  String get downloadStorageCacheCleared => 'Cache cleared';

  @override
  String get downloadStorageCacheBusy =>
      'The cache is in use while a video is playing';

  @override
  String playerResumedFrom(String position) {
    return 'Resumed from $position';
  }

  @override
  String get playerStartOver => 'Start over';

  @override
  String get playerPlayNext => 'Next episode';

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
  String watchProgressContinueFile(String fileName) {
    return 'Continue: $fileName';
  }

  @override
  String watchProgressNextFile(String fileName) {
    return 'Up next: $fileName';
  }

  @override
  String get watchProgressContinueButton => 'Continue';

  @override
  String get watchProgressPlayNextButton => 'Play next';

  @override
  String watchProgressLastFile(String fileName) {
    return 'Last watched: $fileName';
  }

  @override
  String get continueWatchingTitle => 'Continue watching';

  @override
  String get continueWatchingRemove => 'Remove from list';

  @override
  String get recentlyWatchedTitle => 'Recently watched';

  @override
  String get watchSourceUsedBadge => 'You watched this';

  @override
  String get playerEpisodesTitle => 'Episodes';

  @override
  String get playerShowEpisodes => 'Show episodes';

  @override
  String get playerHideEpisodes => 'Hide episodes';

  @override
  String get playerNowPlaying => 'Now playing';

  @override
  String get playerDetailedStats => 'Technical details';

  @override
  String get playerDetailedStatsHint =>
      'Peers, decoder and codecs over the video';

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
  String watchSourceLeechers(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'leechers',
      one: 'leecher',
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
}
