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
  String get animeListTitle => 'Anime List';

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
  String get animeDetailsTitle => 'Anime Details';

  @override
  String get animeDetailsLoading => 'Loading anime details...';

  @override
  String get animeDetailsLoadError => 'Unable to load anime details.';

  @override
  String get watchSourcesTitle => 'Watch Sources';

  @override
  String get watchSourcesOpenButton => 'Watch';

  @override
  String get watchSourcesLoading => 'Loading watch sources...';

  @override
  String get watchSourcesLoadError => 'Unable to load watch sources.';

  @override
  String get watchSourcesEmpty => 'No watch sources found.';

  @override
  String get watchSourcesSearchHint => 'Search sources';

  @override
  String get watchSourcesSearchEmpty => 'No watch sources match your search.';

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
  String get watchSourcesSizeLabel => 'Size';

  @override
  String get watchSourcesTimeLabel => 'Time';

  @override
  String get watchSourcesSeedersLabel => 'Seeders';

  @override
  String get watchSourcesLeechersLabel => 'Leechers';

  @override
  String get watchSourcesDownloadsLabel => 'Downloads';

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
  String get playerWatchFileButton => 'Watch File';

  @override
  String get playerFileSizeLabel => 'Size';

  @override
  String get playerFileTypeLabel => 'Type';

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
  String get playerPlayButton => 'Play';

  @override
  String get playerPauseButton => 'Pause';
}
