// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Iris';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get animeKindTv => 'ТВ';

  @override
  String get animeKindMovie => 'Фильм';

  @override
  String get animeKindOva => 'ОВА';

  @override
  String get animeKindOna => 'ОНА';

  @override
  String get animeStatusReleased => 'Вышло';

  @override
  String get animeStatusOngoing => 'Выходит';

  @override
  String get animeStatusAnnounced => 'Анонс';

  @override
  String animeScoreLabel(String value) {
    return 'Оценка $value';
  }

  @override
  String animeEpisodeProgress(String aired, String total, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'серии',
      many: 'серий',
      few: 'серии',
      one: 'серия',
    );
    return '$aired/$total $_temp0';
  }

  @override
  String get animeListTitle => 'Список аниме';

  @override
  String get animeListLoading => 'Загрузка списка аниме...';

  @override
  String get animeListLoadError => 'Не удалось загрузить список аниме.';

  @override
  String get animeListLoadMoreError => 'Не удалось загрузить ещё аниме.';

  @override
  String get animeListSearchHint => 'Поиск аниме';

  @override
  String get animeListFilterSortButton => 'Фильтры и сортировка';

  @override
  String get animeListFilterSortTitle => 'Фильтры и сортировка';

  @override
  String get animeListSortSectionTitle => 'Сортировка';

  @override
  String get animeListTypeSectionTitle => 'Тип';

  @override
  String get animeListStatusSectionTitle => 'Статус';

  @override
  String get animeListSortPopularity => 'По популярности';

  @override
  String get animeListSortScore => 'По оценке';

  @override
  String get animeListSortAiredOn => 'По дате выхода';

  @override
  String get animeListApplyButton => 'Применить';

  @override
  String get animeListResetButton => 'Сбросить';

  @override
  String get animeListEmpty => 'Сейчас список аниме пуст.';

  @override
  String get animeListSearchEmpty => 'По вашему запросу ничего не найдено.';

  @override
  String get animeListCriteriaEmpty =>
      'Ничего не найдено для выбранных критериев.';

  @override
  String get animeDetailsTitle => 'Детали аниме';

  @override
  String get animeDetailsLoading => 'Загрузка деталей аниме...';

  @override
  String get animeDetailsLoadError => 'Не удалось загрузить детали аниме.';

  @override
  String get watchSourcesTitle => 'Источники просмотра';

  @override
  String get watchSourcesOpenButton => 'Смотреть';

  @override
  String get watchSourcesLoading => 'Загружаем источники просмотра...';

  @override
  String get watchSourcesLoadError =>
      'Не удалось загрузить источники просмотра.';

  @override
  String get watchSourcesEmpty => 'Источники просмотра не найдены.';

  @override
  String get watchSourcesSearchHint => 'Поиск источников';

  @override
  String get watchSourcesSearchEmpty => 'Ничего не найдено по вашему поиску.';

  @override
  String get watchSourcesSortButton => 'Сортировка';

  @override
  String get watchSourcesSortSheetTitle => 'Сортировка';

  @override
  String get watchSourcesSortApplyButton => 'Применить';

  @override
  String get watchSourcesSortSeeders => 'По сидам';

  @override
  String get watchSourcesSortPublishedAt => 'По дате';

  @override
  String get watchSourcesSortDownloads => 'По загрузкам';

  @override
  String get watchSourcesSortTitle => 'По названию';

  @override
  String get watchSourcesSizeLabel => 'Размер';

  @override
  String get watchSourcesTimeLabel => 'Время';

  @override
  String get watchSourcesSeedersLabel => 'Сиды';

  @override
  String get watchSourcesLeechersLabel => 'Личи';

  @override
  String get watchSourcesDownloadsLabel => 'Загрузки';

  @override
  String get watchSourcesPageLinkLabel => 'Ссылка на страницу';

  @override
  String get watchSourcesTorrentLinkLabel => 'Ссылка на torrent';

  @override
  String get watchSourcesMagnetLinkLabel => 'Magnet-ссылка';

  @override
  String get playerTitle => 'Плеер';

  @override
  String get playerOpenButton => 'Смотреть';

  @override
  String get playerSourceTitle => 'Выбор файла';

  @override
  String get playerSourcePreparing => 'Подготавливаем файлы torrent...';

  @override
  String get playerSourceUnsupported =>
      'Этот источник не подходит для просмотра.';

  @override
  String get playerSourceUnableToPrepare =>
      'Не удалось подготовить этот источник.';

  @override
  String get playerWatchFileButton => 'Смотреть файл';

  @override
  String get playerFileSizeLabel => 'Размер';

  @override
  String get playerFileTypeLabel => 'Тип';

  @override
  String get playerPreparing => 'Подготавливаем видео...';

  @override
  String get playerWaitingMetadata => 'Ищем метаданные торрента...';

  @override
  String get playerBuffering => 'Буферизация...';

  @override
  String get playerPreparingMoreBuffer =>
      'Собираем больше данных для старта...';

  @override
  String playerStreamPreparationProgress(int percent) {
    return 'Готовно для старта: $percent%';
  }

  @override
  String playerStreamPreparationSpeed(String value) {
    return 'Текущая скорость: $value';
  }

  @override
  String playerRuntimeStatsSpeed(String value) {
    return 'Скорость $value';
  }

  @override
  String playerRuntimeStatsMemory(String value) {
    return 'Память $value';
  }

  @override
  String playerRuntimeStatsPeers(String value) {
    return 'Пиры $value';
  }

  @override
  String playerRuntimeStatsVideoCodec(String value) {
    return 'Видео $value';
  }

  @override
  String playerRuntimeStatsAudioCodec(String value) {
    return 'Аудио $value';
  }

  @override
  String get playerUnableToStart => 'Не удалось начать воспроизведение.';

  @override
  String get playerUnableToPrepareFirstFrame =>
      'Поток открыт, но плеер не смог подготовить первый кадр.';

  @override
  String get playerUnableToBufferForStart =>
      'Не удалось набрать буфер для старта воспроизведения.';

  @override
  String get playerNoPlayableVideo => 'Подходящее видео не найдено.';

  @override
  String get playerTracksTitle => 'Дорожки воспроизведения';

  @override
  String get playerAudioTracksTitle => 'Аудио';

  @override
  String get playerSubtitleTracksTitle => 'Субтитры';

  @override
  String get playerSubtitleAppearanceTitle => 'Вид субтитров';

  @override
  String get playerSubtitleVisibilityLabel => 'Показывать субтитры';

  @override
  String get playerSubtitleLibassLabel => 'Улучшенный рендер ASS/SSA';

  @override
  String get playerSubtitleLibassDescription =>
      'Использует нативный рендер субтитров для лучшей совместимости с аниме-релизами.';

  @override
  String get playerSubtitleSizeLabel => 'Размер';

  @override
  String get playerSubtitleColorLabel => 'Цвет текста';

  @override
  String get playerSubtitleBackgroundLabel => 'Фон';

  @override
  String get playerSubtitlePositionLabel => 'Положение';

  @override
  String get playerSubtitleResetAction => 'Сбросить';

  @override
  String get playerSubtitleColorWhite => 'Белый';

  @override
  String get playerSubtitleColorYellow => 'Жёлтый';

  @override
  String get playerSubtitleColorCyan => 'Голубой';

  @override
  String get playerSubtitleBackgroundNone => 'Выкл';

  @override
  String get playerSubtitleBackgroundTranslucent => 'Полупрозрачный';

  @override
  String get playerSubtitleBackgroundSolid => 'Плотный';

  @override
  String get playerSubtitlePositionLow => 'Ниже';

  @override
  String get playerSubtitlePositionStandard => 'Стандартно';

  @override
  String get playerSubtitlePositionHigh => 'Выше';

  @override
  String get playerTrackAuto => 'Авто';

  @override
  String get playerTrackOff => 'Выкл';

  @override
  String get playerTracksUnavailable => 'Нет доступных дорожек';

  @override
  String get playerPlayButton => 'Играть';

  @override
  String get playerPauseButton => 'Пауза';
}
