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
  String get watchSourcesOnlineSection => 'Online';

  @override
  String get watchSourcesTorrentsSection => 'Torrents';

  @override
  String get watchSourcesOnlineLoading => 'Looking for online sources';

  @override
  String watchSourcesOnlineAll(int count) {
    return 'All dubs · $count';
  }

  @override
  String get watchSourcesOnlineAllTitle => 'Dubs';

  @override
  String get watchSourcesOnlineLoadError => 'Online sources did not respond.';

  @override
  String watchSourcesOnlineBestQuality(int quality) {
    return 'up to ${quality}p';
  }

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
  String get playerSourcePreparing => 'Preparing torrent files';

  @override
  String get playerSourceUnsupported =>
      'This source is not suitable for playback.';

  @override
  String get playerSourceUnableToPrepare => 'Unable to prepare this source.';

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
  String get playerWaitingMetadata => 'Looking for torrent metadata';

  @override
  String get playerBuffering => 'Buffering';

  @override
  String get playerPreparingMoreBuffer => 'Collecting more buffered data';

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
  String get playerAudioTracksTitle => 'Audio';

  @override
  String get playerSubtitleTracksTitle => 'Subtitles';

  @override
  String get playerSettingsTitle => 'Settings';

  @override
  String get playerDecoderSettingsTitle => 'Decoder';

  @override
  String get playerDecoderSettingsDescription =>
      'Change this only if video stutters or shows green frames on your device. Technical details below show the decoder in use.';

  @override
  String get playerDecoderAutoSafe => 'Auto (recommended)';

  @override
  String get playerDecoderMediacodec => 'MediaCodec';

  @override
  String get playerDecoderMediacodecCopy => 'MediaCodec (copy-back)';

  @override
  String get playerDecoderSoftwareOnly => 'Software only';

  @override
  String get playerSubtitleAppearanceTitle => 'Subtitle Appearance';

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
      'A custom colour, background or position replaces the release\'s styling: styled signs become plain text.';

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
      'The decoder and ASS rendering apply by restarting the video where it is.';

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
  String get downloadsLoading => 'Loading downloaded files...';

  @override
  String get savedTorrentsLoading => 'Loading saved torrents...';

  @override
  String get downloadDeleteFailed =>
      'Unable to delete the files. Close the file if it is open and try again';

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
  String get continueWatchingStoppedAtLabel => 'Stopped at';

  @override
  String get continueWatchingFinishedLabel => 'Watched to the end';

  @override
  String get animeListHeadingPopularity => 'Popular';

  @override
  String get animeListHeadingScore => 'Top rated';

  @override
  String get animeListHeadingAiredOn => 'Latest';

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
  String playerSeekBackward(int seconds) {
    return 'Back $seconds s';
  }

  @override
  String playerSeekForward(int seconds) {
    return 'Forward $seconds s';
  }

  @override
  String get playerMute => 'Mute';

  @override
  String get playerUnmute => 'Unmute';

  @override
  String get playerAudioAndSubtitles => 'Audio & subtitles';

  @override
  String get playerEnterFullscreen => 'Full screen';

  @override
  String get playerExitFullscreen => 'Exit full screen';

  @override
  String get playerCloseEpisodes => 'Close episodes';

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
  String get animeDetailsShowCover => 'Show the original cover';

  @override
  String get animeDetailsShowHalftone => 'Show the halftone';

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
  String get savedTorrentsPasteHint =>
      'Ctrl+V adds a magnet link from the clipboard';

  @override
  String get downloadsFilesTitle => 'Files';

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
}
