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
  String get navigationCatalog => 'Каталог';

  @override
  String get navigationDownloads => 'Загрузки';

  @override
  String get downloadsTitle => 'Загрузки';

  @override
  String get downloadsOpenButton => 'Скачать';

  @override
  String get downloadsEmpty => 'Загруженные серии появятся здесь.';

  @override
  String get downloadSelectionTitle => 'Скачать файл';

  @override
  String get downloadSelectionPreparing => 'Получаем список файлов торрента...';

  @override
  String get downloadSelectionUnsupported =>
      'В этом источнике нет поддерживаемых видеофайлов.';

  @override
  String get downloadSelectionUnableToPrepare =>
      'Не удалось получить файлы из этого источника.';

  @override
  String get downloadUnableToQueue =>
      'Не удалось добавить файл в очередь загрузок.';

  @override
  String get downloadFileButton => 'Скачать';

  @override
  String get downloadAddingToQueue => 'Добавляем в очередь...';

  @override
  String get downloadManagerUnableToLoad =>
      'Не удалось открыть список загрузок.';

  @override
  String get downloadStorageTitle => 'Память приложения';

  @override
  String get downloadStorageTotal => 'Всего занято приложением';

  @override
  String get downloadStorageContent => 'Офлайн-контент';

  @override
  String get downloadStorageCache => 'Кэш';

  @override
  String get downloadStatusQueued => 'В очереди';

  @override
  String get downloadStatusDownloading => 'Загружается';

  @override
  String get downloadStatusPaused => 'На паузе';

  @override
  String get downloadStatusCompleted => 'Загружено';

  @override
  String get downloadStatusFailed => 'Ошибка';

  @override
  String downloadPeers(int count) {
    return 'Пиры: $count';
  }

  @override
  String get downloadFailedMessage => 'Загрузка остановилась из-за ошибки.';

  @override
  String get downloadWatchButton => 'Смотреть';

  @override
  String get downloadPauseButton => 'Пауза';

  @override
  String get downloadResumeButton => 'Продолжить';

  @override
  String get downloadDeleteButton => 'Удалить';

  @override
  String get downloadCancelButton => 'Отмена';

  @override
  String get downloadDeleteTitle => 'Удалить загрузку?';

  @override
  String downloadDeleteMessage(String name) {
    return 'Файл «$name» будет удалён с устройства.';
  }

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
  String get animeDetailsLoading => 'Загрузка деталей аниме...';

  @override
  String get animeDetailsLoadError => 'Не удалось загрузить детали аниме.';

  @override
  String get watchSourcesTitle => 'Источники';

  @override
  String get watchSourcesOpenButton => 'Смотреть';

  @override
  String get watchSourcesLoading => 'Загружаем источники...';

  @override
  String get watchSourcesLoadError => 'Не удалось загрузить источники.';

  @override
  String get watchSourcesEmpty => 'Источники не найдены.';

  @override
  String get watchSourcesOnlineSection => 'Онлайн';

  @override
  String get watchSourcesTorrentsSection => 'Торренты';

  @override
  String get watchSourcesOnlineLoading => 'Ищем онлайн-источники';

  @override
  String get watchSourcesOnlineLoadError => 'Онлайн-источники не ответили.';

  @override
  String watchSourcesOnlineBestQuality(int quality) {
    return 'до ${quality}p';
  }

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
  String get playerSourcePreparing => 'Подготавливаем файлы torrent';

  @override
  String get playerSourceUnsupported =>
      'Этот источник не подходит для просмотра.';

  @override
  String get playerSourceUnableToPrepare =>
      'Не удалось подготовить этот источник.';

  @override
  String get playerSourceEpisodesTitle => 'Выбор серии';

  @override
  String get playerSourceEpisodesPreparing => 'Загружаем серии';

  @override
  String playerEpisodeMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get playerPreparing => 'Подготавливаем видео';

  @override
  String get playerWaitingMetadata => 'Ищем метаданные торрента';

  @override
  String get playerBuffering => 'Буферизация';

  @override
  String get playerPreparingMoreBuffer => 'Собираем больше данных для старта';

  @override
  String get playerWaitNoPeers => 'Пиров пока нет';

  @override
  String playerWaitPeers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count пира',
      many: '$count пиров',
      few: '$count пира',
      one: '$count пир',
    );
    return '$_temp0';
  }

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
  String get playerAudioTracksTitle => 'Аудио';

  @override
  String get playerSubtitleTracksTitle => 'Субтитры';

  @override
  String get playerSettingsTitle => 'Настройки';

  @override
  String get playerDecoderSettingsTitle => 'Декодер';

  @override
  String get playerDecoderSettingsDescription =>
      'Меняйте это, только если видео тормозит или показывает зелёные кадры на вашем устройстве. Текущий декодер видно в технических подробностях ниже.';

  @override
  String get playerDecoderAutoSafe => 'Авто (рекомендуется)';

  @override
  String get playerDecoderMediacodec => 'MediaCodec';

  @override
  String get playerDecoderMediacodecCopy => 'MediaCodec (с копированием)';

  @override
  String get playerDecoderSoftwareOnly => 'Только программный';

  @override
  String get playerSubtitleAppearanceTitle => 'Вид субтитров';

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
  String get playerSubtitleSizeSample => 'Аа';

  @override
  String get playerSubtitleSizeSmaller => 'Мельче';

  @override
  String get playerSubtitleSizeNormal => 'Обычный';

  @override
  String get playerSubtitleSizeLarger => 'Крупнее';

  @override
  String get playerSubtitleSizeLargest => 'Самый крупный';

  @override
  String get playerSubtitleOverrideHint =>
      'Свой цвет, фон и положение заменяют оформление релиза: стилизованные надписи станут обычным текстом.';

  @override
  String get playerAdvancedTitle => 'Дополнительно';

  @override
  String playerAdvancedSummary(String decoder, String ass) {
    return 'Декодер: $decoder · рендер ASS: $ass';
  }

  @override
  String get playerSettingOn => 'вкл';

  @override
  String get playerSettingOff => 'выкл';

  @override
  String get playerDecoderAutoShort => 'авто';

  @override
  String get playerRestartHint =>
      'Декодер и рендер ASS применяются перезапуском видео с того же места.';

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
  String get playerSubtitlePositionStandard => 'Обычно';

  @override
  String get playerSubtitlePositionHigh => 'Выше';

  @override
  String get playerTrackAuto => 'Авто';

  @override
  String get playerTrackOff => 'Выкл';

  @override
  String get playerTracksUnavailable => 'Нет доступных дорожек';

  @override
  String get invalidRouteArgumentsMessage =>
      'Этот экран был открыт с некорректными данными навигации.';

  @override
  String get playerPlayButton => 'Играть';

  @override
  String get playerPauseButton => 'Пауза';

  @override
  String get navigationSavedTorrents => 'Раздачи';

  @override
  String get savedTorrentsTitle => 'Раздачи';

  @override
  String get savedTorrentsAddButton => 'Добавить magnet';

  @override
  String get savedTorrentsEmptyTitle => 'Пока нет сохранённых раздач';

  @override
  String get savedTorrentsEmptyMessage =>
      'Вставьте magnet-ссылку, чтобы смотреть или скачать. Сохранённые ссылки останутся здесь.';

  @override
  String get savedTorrentsAddTitle => 'Добавить magnet-ссылку';

  @override
  String get savedTorrentsMagnetLabel => 'Magnet-ссылка';

  @override
  String get savedTorrentsPasteTooltip => 'Вставить из буфера';

  @override
  String get savedTorrentsNameLabel => 'Название';

  @override
  String get savedTorrentsNameHelper =>
      'Если оставить пустым, возьмём из ссылки';

  @override
  String get savedTorrentsInvalidMagnet =>
      'Это не magnet-ссылка с хэшем раздачи (xt=urn:btih:…).';

  @override
  String get savedTorrentsSaveButton => 'Сохранить';

  @override
  String get savedTorrentsAdded => 'Раздача сохранена';

  @override
  String savedTorrentsDuplicate(String title) {
    return 'Уже сохранена как «$title»';
  }

  @override
  String get savedTorrentsMoreTooltip => 'Ещё';

  @override
  String get savedTorrentsRename => 'Переименовать';

  @override
  String get savedTorrentsCopyLink => 'Копировать ссылку';

  @override
  String get savedTorrentsLinkCopied => 'Ссылка скопирована';

  @override
  String get savedTorrentsDelete => 'Удалить';

  @override
  String savedTorrentsDeleteTitle(String title) {
    return 'Удалить «$title»?';
  }

  @override
  String get savedTorrentsDeleteMessage =>
      'Удалится только сохранённая ссылка. Скачанные файлы останутся в «Загрузках».';

  @override
  String savedTorrentsAddedOn(String date) {
    return 'Добавлена $date';
  }

  @override
  String savedTorrentsOpenedOn(String date) {
    return 'Открывали $date';
  }

  @override
  String get downloadStorageClearCache => 'Очистить';

  @override
  String get downloadStorageCacheCleared => 'Кэш очищен';

  @override
  String get downloadStorageCacheBusy => 'Кэш занят: сейчас идёт просмотр';

  @override
  String get downloadsLoading => 'Загружаем список файлов...';

  @override
  String get savedTorrentsLoading => 'Загружаем раздачи...';

  @override
  String get downloadDeleteFailed =>
      'Не удалось удалить файлы. Закройте файл, если он открыт, и попробуйте снова';

  @override
  String playerResumedFrom(String position) {
    return 'Продолжаем с $position';
  }

  @override
  String get playerStartOver => 'С начала';

  @override
  String playerResumingFrom(String position) {
    return 'Продолжим с $position';
  }

  @override
  String get playerStartingOver => 'Начнём с начала';

  @override
  String get playerStartedOver => 'Смотрим с начала';

  @override
  String playerResumeFromAction(String position) {
    return 'С $position';
  }

  @override
  String get playerPlayNext => 'Следующая серия';

  @override
  String get playerSkipOpening => 'Пропустить опенинг';

  @override
  String get playerSkipRecap => 'Пропустить пересказ';

  @override
  String playerSkipForward(int seconds) {
    return '+$seconds с';
  }

  @override
  String playerSkipForwardTooltip(int seconds) {
    return 'Вперёд на $seconds с';
  }

  @override
  String get watchProgressWatched => 'Просмотрено';

  @override
  String watchProgressStoppedAt(String position, String duration) {
    return 'Остановились на $position из $duration';
  }

  @override
  String watchProgressContinueFile(String fileName) {
    return 'Продолжить: $fileName';
  }

  @override
  String watchProgressNextFile(String fileName) {
    return 'Дальше: $fileName';
  }

  @override
  String get watchProgressContinueButton => 'Продолжить';

  @override
  String get watchProgressPlayNextButton => 'Смотреть дальше';

  @override
  String get watchProgressWatchButton => 'Смотреть';

  @override
  String watchProgressLastFile(String fileName) {
    return 'Последняя: $fileName';
  }

  @override
  String get continueWatchingTitle => 'Продолжить просмотр';

  @override
  String get continueWatchingRemove => 'Убрать из списка';

  @override
  String get continueWatchingStoppedAtLabel => 'Остановились на';

  @override
  String get continueWatchingFinishedLabel => 'Досмотрено';

  @override
  String get animeListHeadingPopularity => 'Популярное';

  @override
  String get animeListHeadingScore => 'Высокий рейтинг';

  @override
  String get animeListHeadingAiredOn => 'Новинки';

  @override
  String get recentlyWatchedTitle => 'Недавно смотрели';

  @override
  String get watchSourceUsedBadge => 'Вы смотрели';

  @override
  String get playerEpisodesTitle => 'Серии';

  @override
  String get playerShowEpisodes => 'Показать серии';

  @override
  String get playerHideEpisodes => 'Скрыть серии';

  @override
  String get playerNowPlaying => 'Сейчас';

  @override
  String get playerDetailedStats => 'Технические подробности';

  @override
  String get playerDetailedStatsHint => 'Пиры, декодер и кодеки поверх видео';

  @override
  String get playerBack => 'Назад';

  @override
  String playerEpisodeNumber(int number) {
    return 'Серия $number';
  }

  @override
  String playerEpisodePosition(int position, int total) {
    return '$position из $total';
  }

  @override
  String playerEpisodeOfTotal(int total) {
    return 'из $total';
  }

  @override
  String playerTimeLeft(String time) {
    return 'Осталось $time';
  }

  @override
  String playerSeekBackward(int seconds) {
    return 'Назад на $seconds с';
  }

  @override
  String playerSeekForward(int seconds) {
    return 'Вперёд на $seconds с';
  }

  @override
  String get playerMute => 'Выключить звук';

  @override
  String get playerUnmute => 'Включить звук';

  @override
  String get playerAudioAndSubtitles => 'Аудио и субтитры';

  @override
  String get playerEnterFullscreen => 'Во весь экран';

  @override
  String get playerExitFullscreen => 'Выйти из полноэкранного режима';

  @override
  String get playerCloseEpisodes => 'Закрыть список серий';

  @override
  String playerRate(String value) {
    return '$value/с';
  }

  @override
  String get byteUnitB => 'Б';

  @override
  String get byteUnitKB => 'КБ';

  @override
  String get byteUnitMB => 'МБ';

  @override
  String get byteUnitGB => 'ГБ';

  @override
  String playerTimePosition(String position, String duration) {
    return '$position из $duration';
  }

  @override
  String get playerSeekBarLabel => 'Позиция воспроизведения';

  @override
  String get animeDetailsChooseSourceButton => 'Выбрать источник';

  @override
  String animeEpisodeCount(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'серии',
      many: 'серий',
      few: 'серии',
      one: 'серия',
    );
    return '$value $_temp0';
  }

  @override
  String watchSourceSeeders(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'сида',
      many: 'сидов',
      few: 'сида',
      one: 'сид',
    );
    return '$value $_temp0';
  }

  @override
  String watchSourceLeechers(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'личера',
      many: 'личеров',
      few: 'личера',
      one: 'личер',
    );
    return '$value $_temp0';
  }

  @override
  String watchSourceDownloads(String value, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'загрузки',
      many: 'загрузок',
      few: 'загрузки',
      one: 'загрузка',
    );
    return '$value $_temp0';
  }

  @override
  String get searchClearTooltip => 'Очистить';

  @override
  String get searchCancelButton => 'Отмена';

  @override
  String get animeDetailsFactKind => 'Тип';

  @override
  String get animeDetailsFactStatus => 'Статус';

  @override
  String get animeDetailsFactEpisodes => 'Эпизоды';

  @override
  String get animeDetailsFactScore => 'Оценка';

  @override
  String get animeDetailsFactAired => 'Выход';

  @override
  String animeDetailsEpisodesAired(String aired, String total) {
    return '$aired из $total';
  }

  @override
  String get animeDetailsDescriptionTitle => 'Описание';

  @override
  String get animeDetailsShowCover => 'Показать оригинал обложки';

  @override
  String get animeDetailsShowHalftone => 'Показать растр';

  @override
  String get watchSourcesColumnRelease => 'Релиз';

  @override
  String get watchSourcesColumnSize => 'Размер';

  @override
  String get watchSourcesColumnSeeders => 'Сиды';

  @override
  String get watchSourcesColumnDownloads => 'Загрузки';

  @override
  String get watchSourcesColumnDate => 'Дата';

  @override
  String get savedTorrentsPasteHint =>
      'Ctrl+V — добавить magnet-ссылку из буфера';

  @override
  String get downloadsFilesTitle => 'Файлы';

  @override
  String commonShowMore(int count) {
    return 'Ещё $count';
  }

  @override
  String get commonShowLess => 'Свернуть';

  @override
  String get animeKindSpecial => 'Спешл';

  @override
  String get animeKindTvSpecial => 'ТВ-спешл';

  @override
  String get animeDetailsRelatedTitle => 'Связанные';

  @override
  String get animeRelationPrequel => 'Предыстория';

  @override
  String get animeRelationSequel => 'Продолжение';

  @override
  String get animeRelationParentStory => 'Основная история';

  @override
  String get animeRelationFullStory => 'Полная история';

  @override
  String get animeRelationSideStory => 'Побочная история';

  @override
  String get animeRelationAlternativeSetting => 'Альтернативная вселенная';

  @override
  String get animeRelationAlternativeVersion => 'Альтернативная версия';

  @override
  String get animeRelationSpinOff => 'Ответвление';

  @override
  String get animeRelationSummary => 'Пересказ';

  @override
  String get animeRelationCharacter => 'Общие персонажи';

  @override
  String get animeRelationOther => 'Другое';

  @override
  String get navigationProfile => 'Профиль';

  @override
  String get profileSignInTitle => 'Список на Шикимори';

  @override
  String get profileSignInMessage =>
      'Войдите, чтобы отмечать аниме в своём списке на Шикимори прямо из приложения.';

  @override
  String get profileSignInButton => 'Войти через Шикимори';

  @override
  String get profileSignInUnavailable => 'Вход не настроен в этой сборке.';

  @override
  String get profileSigningIn => 'Ждём Шикимори';

  @override
  String get profileSignInNetworkError =>
      'Шикимори не ответил. Попробуйте ещё раз.';

  @override
  String get profileSignInRejected =>
      'Шикимори не пустил приложение. Попробуйте ещё раз.';

  @override
  String get profileSessionExpired =>
      'Шикимори завершил сессию. Войдите снова.';

  @override
  String get profileAccountCaption => 'Аккаунт Шикимори';

  @override
  String get profileSignOut => 'Выйти';
}
