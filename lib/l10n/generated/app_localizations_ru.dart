// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get downloadFilesButton => 'Файлы';

  @override
  String get downloadFilesTitle => 'Освободить место';

  @override
  String get downloadFilesTemporary => 'Временные файлы';

  @override
  String get downloadFilesTemporaryHint => 'Скачанные серии сохранятся.';

  @override
  String get downloadFilesTemporaryBusy =>
      'Очистка недоступна во время просмотра.';

  @override
  String get downloadFilesClearTemporary => 'Очистить временные файлы';

  @override
  String get downloadFilesClearingTemporary => 'Очистка временных файлов';

  @override
  String get downloadFilesTemporaryCleared => 'Временные файлы удалены';

  @override
  String get downloadFilesClearFailed => 'Не удалось удалить временные файлы.';

  @override
  String get downloadFilesSaved => 'Скачанные серии';

  @override
  String get downloadFilesEmpty => 'Скачанных серий пока нет.';

  @override
  String get downloadFilesUnavailable =>
      'Не удалось определить размер временных файлов.';

  @override
  String get downloadQueueButton => 'Очередь';

  @override
  String get downloadQueueCurrent => 'Сейчас скачивается';

  @override
  String get downloadQueueWaiting => 'Далее';

  @override
  String get downloadQueueMoveUp => 'Выше';

  @override
  String get downloadQueueMoveDown => 'Ниже';

  @override
  String get downloadQueueMove => 'Переместить серию';

  @override
  String get downloadQueueChanged => 'Порядок загрузки изменён';

  @override
  String get downloadQueueReorderFailed =>
      'Не удалось изменить порядок очереди.';

  @override
  String get downloadQueuePaused => 'На паузе';

  @override
  String get downloadQueueAttention => 'Ошибки';

  @override
  String get downloadQueueFinished => 'Все серии скачаны.';

  @override
  String get downloadQueueNoWaiting => 'В очереди больше ничего нет.';

  @override
  String downloadBytesProgress(String downloaded, String total) {
    return '$downloaded из $total';
  }

  @override
  String downloadBytesDownloaded(String size) {
    return 'Скачано $size';
  }

  @override
  String get appName => 'Iris';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonSignIn => 'Войти';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSignOut => 'Выйти';

  @override
  String get navigationCatalog => 'Каталог';

  @override
  String get navigationDownloads => 'Загрузки';

  @override
  String get navigationDownloadsActive => 'идёт скачивание';

  @override
  String get downloadsOpenButton => 'Скачать';

  @override
  String get downloadsEmptyTitle => 'Пока нет загрузок';

  @override
  String get downloadsEmpty =>
      'Серии можно скачать со страницы аниме, чтобы смотреть без интернета.';

  @override
  String get downloadSelectionTitle => 'Скачать файлы';

  @override
  String get downloadUnableToQueue =>
      'Не удалось добавить файл в очередь загрузок.';

  @override
  String get downloadFileButton => 'Скачать';

  @override
  String get downloadAddingToQueue => 'Добавление в очередь';

  @override
  String downloadSelectionLoading(int percent) {
    return 'Загружается · $percent %';
  }

  @override
  String get downloadManagerUnableToLoad =>
      'Не удалось открыть список загрузок.';

  @override
  String get downloadStatusQueued => 'В очереди';

  @override
  String get downloadStatusDownloading => 'Загружается';

  @override
  String get downloadStatusPaused => 'На паузе';

  @override
  String get downloadStatusCompleted => 'Готово';

  @override
  String get downloadStatusFailed => 'Ошибка';

  @override
  String get downloadNotificationTitle => 'Загрузка';

  @override
  String get downloadNotificationChannelName => 'Загрузки';

  @override
  String get downloadNotificationChannelDescription =>
      'Ход загрузки серий и обновлений приложения';

  @override
  String get downloadFailedMessage => 'Ошибка загрузки';

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
    return 'Это удалит «$name» с устройства.';
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
  String get animeListLoading => 'Загрузка списка аниме';

  @override
  String get animeListLoadError => 'Не удалось загрузить список аниме.';

  @override
  String get animeListLoadMoreError => 'Не удалось загрузить дальше.';

  @override
  String get animeListSearchHint => 'Поиск аниме';

  @override
  String get animeListFilterSortButton => 'Фильтры и сортировка';

  @override
  String get animeListSortSectionTitle => 'Сортировка';

  @override
  String get animeListTypeSectionTitle => 'Тип';

  @override
  String get animeListStatusSectionTitle => 'Статус';

  @override
  String get animeListSortPopularity => 'Популярное';

  @override
  String get animeListSortScore => 'Рейтинг';

  @override
  String get animeListSortAiredOn => 'Новинки';

  @override
  String get animeListResetButton => 'Сбросить';

  @override
  String get animeListEmpty => 'Список пуст.';

  @override
  String get animeListSearchEmpty => 'Ничего не найдено.';

  @override
  String get animeListCriteriaEmpty => 'С такими фильтрами ничего не найдено.';

  @override
  String get animeDetailsLoading => 'Загрузка аниме';

  @override
  String get animeDetailsLoadError => 'Не удалось загрузить аниме.';

  @override
  String get watchSourcesTitle => 'Источники';

  @override
  String get watchSourcesLoading => 'Загрузка источников';

  @override
  String get watchSourcesLoadError => 'Не удалось загрузить источники.';

  @override
  String get watchSourcesEmpty => 'Источники не найдены.';

  @override
  String get watchSourcesOnlineSection => 'Онлайн';

  @override
  String get watchSourcesTorrentsSection => 'Торренты';

  @override
  String get watchSourcesOnlineLoading => 'Поиск онлайн-источников';

  @override
  String get watchSourcesOnlineLoadError => 'Онлайн-источники не ответили.';

  @override
  String get onlineQualityTitle => 'Качество';

  @override
  String get onlineQualityAuto => 'Авто';

  @override
  String onlineQualityHeight(int height) {
    return '${height}p';
  }

  @override
  String watchSourcesOnlineBestQuality(int quality) {
    return 'до ${quality}p';
  }

  @override
  String get watchSourcesSearchHint => 'Поиск источников';

  @override
  String get watchSourcesSearchEmpty => 'Ничего не найдено.';

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
  String get watchSourcesSortSize => 'По размеру';

  @override
  String get watchSourcesSortTitle => 'По названию';

  @override
  String get playerSourceTitle => 'Выбор файла';

  @override
  String get playerSourcePreparing => 'Подготовка файлов торрента';

  @override
  String get playerSourceUnsupported => 'Источник не поддерживается.';

  @override
  String get playerSourceUnableToPrepare => 'Не удалось открыть источник.';

  @override
  String get playerSourceEpisodesTitle => 'Выбор серии';

  @override
  String get playerSourceEpisodesPreparing => 'Загрузка серий';

  @override
  String playerEpisodeMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String get playerPreparing => 'Подготовка видео';

  @override
  String get playerBuffering => 'Буферизация';

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
  String get playerUnableToPrepareFirstFrame => 'Не удалось показать видео.';

  @override
  String get playerAudioTracksTitle => 'Аудио';

  @override
  String get playerSubtitleTracksTitle => 'Субтитры';

  @override
  String get playerSettingsTitle => 'Настройки';

  @override
  String get playerLockScreen => 'Заблокировать экран';

  @override
  String get playerUnlockScreen => 'Разблокировать';

  @override
  String get playerScreenLocked =>
      'Экран заблокирован. Коснитесь, чтобы разблокировать';

  @override
  String get playerBrightness => 'Яркость';

  @override
  String get playerDecoderSettingsTitle => 'Декодер';

  @override
  String get playerDecoderSettingsDescription =>
      'Меняйте, если видео тормозит или отображается с артефактами.';

  @override
  String get playerDecoderAutoSafe => 'Авто (рекомендуется)';

  @override
  String get playerDecoderMediacodec => 'MediaCodec';

  @override
  String get playerDecoderMediacodecCopy => 'MediaCodec (с копированием)';

  @override
  String get playerDecoderSoftwareOnly => 'Только программный';

  @override
  String get playerPlaybackSectionTitle => 'Воспроизведение';

  @override
  String get playerPlaybackSpeedTitle => 'Скорость воспроизведения';

  @override
  String get playerVideoFitTitle => 'Масштаб кадра';

  @override
  String playerPlaybackRate(double rate) {
    final intl.NumberFormat rateNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String rateString = rateNumberFormat.format(rate);

    return '$rateString×';
  }

  @override
  String get playerSubtitleAppearanceTitle => 'Вид субтитров';

  @override
  String get playerSubtitleLibassLabel => 'Улучшенный рендер ASS/SSA';

  @override
  String get playerSubtitleLibassDescription =>
      'Сохраняет шрифты, стили и положение надписей в ASS/SSA.';

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
  String get playerSubtitleSizeLargest => 'Очень крупный';

  @override
  String get playerSubtitleOverrideHint =>
      'Свой цвет, фон или положение отключат стили релиза: надписи станут обычным текстом.';

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
      'Смена декодера или рендера ASS перезапустит видео с того же места.';

  @override
  String get playerDecoderRestartHint =>
      'Смена декодера перезапустит видео с того же места.';

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
  String get playerTrackUnnamed => 'Дорожка';

  @override
  String get playerTrackLanguageEnglish => 'Английский';

  @override
  String get playerTrackLanguageJapanese => 'Японский';

  @override
  String get playerTrackLanguageRussian => 'Русский';

  @override
  String get playerTracksUnavailable => 'Нет доступных дорожек';

  @override
  String get invalidRouteArgumentsMessage => 'Не удалось открыть страницу.';

  @override
  String get playerPlayButton => 'Воспроизвести';

  @override
  String get playerPauseButton => 'Пауза';

  @override
  String get savedTorrentsAddButton => 'Добавить раздачу';

  @override
  String get savedTorrentsAddTitle => 'Добавить раздачу';

  @override
  String get savedTorrentsMagnetLabel => 'Magnet-ссылка';

  @override
  String get savedTorrentsPasteTooltip => 'Вставить из буфера';

  @override
  String get savedTorrentsNameLabel => 'Название';

  @override
  String get savedTorrentsInvalidMagnet =>
      'Нужна magnet-ссылка с хэшем (xt=urn:btih:…).';

  @override
  String get savedTorrentsSaveButton => 'Сохранить';

  @override
  String savedTorrentsDuplicate(String title) {
    return 'Уже добавлена как «$title»';
  }

  @override
  String get commonMoreActions => 'Ещё';

  @override
  String get savedTorrentsRename => 'Переименовать';

  @override
  String get savedTorrentsCopyLink => 'Копировать ссылку';

  @override
  String get savedTorrentsLinkCopied => 'Ссылка скопирована';

  @override
  String get savedTorrentsDelete => 'Удалить';

  @override
  String savedTorrentsAddedOn(String date) {
    return 'Добавлена $date';
  }

  @override
  String savedTorrentsOpenedOn(String date) {
    return 'Открыта $date';
  }

  @override
  String get downloadStorageClearCache => 'Очистить';

  @override
  String get downloadsLoading => 'Загрузка списка файлов';

  @override
  String get downloadDeleteFailed =>
      'Не удалось удалить файлы. Возможно, один из них открыт.';

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
  String get playerPartOpening => 'Опенинг';

  @override
  String get playerPartEnding => 'Эндинг';

  @override
  String get playerPartRecap => 'Рекап';

  @override
  String get playerSkipOpening => 'Пропустить опенинг';

  @override
  String get playerSkipRecap => 'Пропустить рекап';

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
  String get watchProgressContinueButton => 'Продолжить';

  @override
  String get watchProgressPlayNextButton => 'Смотреть дальше';

  @override
  String get watchProgressWatchButton => 'Смотреть';

  @override
  String watchProgressLastFile(String fileName) {
    return 'Файл: $fileName';
  }

  @override
  String get continueWatchingTitle => 'Продолжить просмотр';

  @override
  String get continueWatchingRemove => 'Убрать из списка';

  @override
  String get animeListHeadingPopularity => 'Популярное';

  @override
  String get animeListHeadingScore => 'Высокий рейтинг';

  @override
  String get animeListHeadingAiredOn => 'Новинки';

  @override
  String get recentlyWatchedTitle => 'Недавно смотрели';

  @override
  String get watchSourceUsedBadge => 'Смотрели';

  @override
  String get playerEpisodesTitle => 'Серии';

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
  String get playerMute => 'Выключить звук';

  @override
  String get playerUnmute => 'Включить звук';

  @override
  String get playerAudioAndSubtitles => 'Аудио и субтитры';

  @override
  String get playerPictureInPicture => 'Картинка в картинке';

  @override
  String get playerPictureInPictureOff =>
      'Картинка в картинке выключена для Iris в настройках системы.';

  @override
  String get playerPictureInPictureFailed => 'Не удалось открыть мини-плеер.';

  @override
  String get playerRestoreFromPictureInPicture => 'Вернуть плеер';

  @override
  String get playerClosePictureInPicture => 'Закрыть мини-плеер';

  @override
  String get playerEnterFullscreen => 'Во весь экран';

  @override
  String get playerExitFullscreen => 'Выйти из полноэкранного режима';

  @override
  String get playerCloseEpisodes => 'Закрыть список серий';

  @override
  String get playerZoomFill => 'Заполнить экран';

  @override
  String get playerZoomFit => 'Вписать в экран';

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
  String get animeDetailsFactEpisodes => 'Серии';

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
  String get profileSignInTitle => 'Аккаунт Шикимори';

  @override
  String get profileSignInMessage =>
      'Синхронизация списков, отметок серий и друзей с Шикимори';

  @override
  String get profileSignInUnavailable => 'В этой сборке вход не настроен';

  @override
  String get profileSigningIn => 'Ожидание Шикимори';

  @override
  String get profileSignInNetworkError => 'Нет ответа от Шикимори.';

  @override
  String get profileSignInRejected => 'Не удалось войти.';

  @override
  String get profileSessionExpired => 'Сессия истекла. Войдите снова.';

  @override
  String get userRateTitle => 'Мой список';

  @override
  String get userRateAdd => 'Добавить в список';

  @override
  String get userRateRemove => 'Убрать из списка';

  @override
  String get userRateStatusPlanned => 'Запланировано';

  @override
  String get userRateStatusWatching => 'Смотрю';

  @override
  String get userRateStatusRewatching => 'Пересматриваю';

  @override
  String get userRateStatusCompleted => 'Просмотрено';

  @override
  String get userRateStatusOnHold => 'Отложено';

  @override
  String get userRateStatusDropped => 'Брошено';

  @override
  String get userRateEpisodeLess => 'На серию меньше';

  @override
  String get userRateEpisodeMore => 'На серию больше';

  @override
  String userRateEpisodesWatched(String count) {
    return 'Просмотрено серий: $count';
  }

  @override
  String get userRateLoadError => 'Не удалось загрузить список.';

  @override
  String get userRateSaveError => 'Не удалось сохранить на Шикимори.';

  @override
  String userRateScore(int score) {
    return 'Оценка: $score';
  }

  @override
  String get userRateRate => 'Оценить';

  @override
  String get userRateNoScore => 'Без оценки';

  @override
  String get animeListHideCompleted => 'Кроме просмотренного';

  @override
  String get animeListGenresSectionTitle => 'Жанры';

  @override
  String get animeListSeasonSectionTitle => 'Сезон';

  @override
  String animeSeasonWinter(String year) {
    return 'Зима $year';
  }

  @override
  String animeSeasonSpring(String year) {
    return 'Весна $year';
  }

  @override
  String animeSeasonSummer(String year) {
    return 'Лето $year';
  }

  @override
  String animeSeasonFall(String year) {
    return 'Осень $year';
  }

  @override
  String animeListDecade(String decade) {
    return '$decade-е';
  }

  @override
  String get animeListBefore2000 => 'До 2000';

  @override
  String get animeListRatingSectionTitle => 'Возрастной рейтинг';

  @override
  String get animeListDurationSectionTitle => 'Длина серии';

  @override
  String get animeDurationShort => 'До 10 мин';

  @override
  String get animeDurationStandard => 'До 30 мин';

  @override
  String get animeDurationLong => 'Больше 30 мин';

  @override
  String animeNextEpisodeToday(String time) {
    return 'сегодня в $time';
  }

  @override
  String animeNextEpisodeTomorrow(String time) {
    return 'завтра в $time';
  }

  @override
  String animeNextEpisodeInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return 'через $_temp0';
  }

  @override
  String animeNextEpisode(int episode, String when) {
    return 'Серия $episode · $when';
  }

  @override
  String profileListEmpty(String status) {
    return 'В «$status» пусто';
  }

  @override
  String get profileListLoadError => 'Не удалось загрузить список.';

  @override
  String get profileListLoading => 'Загрузка списка';

  @override
  String get profileFriendsTab => 'Друзья';

  @override
  String get profileFriendsEmpty => 'На Шикимори пока нет друзей.';

  @override
  String get profileFriendsLoadError => 'Не удалось загрузить список друзей.';

  @override
  String get profileFriendsLoading => 'Загрузка друзей';

  @override
  String get animeDetailsFriendsTitle => 'Друзья';

  @override
  String get appUpdateDownload => 'Скачать';

  @override
  String get appUpdateLater => 'Позже';

  @override
  String get appUpdateOpenFailed => 'Не удалось открыть ссылку на скачивание.';

  @override
  String get appUpdateNotificationTitle => 'Обновление Iris';

  @override
  String appUpdateNoticeAvailable(String version) {
    return 'Доступна версия $version';
  }

  @override
  String get appUpdateNoticeDownloading => 'Скачивание';

  @override
  String appUpdateNoticeDownloadingVersion(String version) {
    return 'Скачивание $version';
  }

  @override
  String get appUpdateNoticeReady => 'Обновление готово';

  @override
  String get appUpdateNoticeRestartReady => 'Готово к перезапуску';

  @override
  String get appUpdateNoticePermissionNeeded => 'Нужно разрешение';

  @override
  String get appUpdateNoticeInstallFailed => 'Не удалось установить';

  @override
  String get appUpdateNoticeFailed => 'Не удалось скачать';

  @override
  String get appUpdateNoticeVerifying => 'Проверка файла';

  @override
  String get appUpdateNoticeInstalling => 'Запуск установщика';

  @override
  String get appUpdateNoticeRestarting => 'Перезапуск Iris';

  @override
  String get appUpdateWhatsNew => 'Что нового';

  @override
  String get appUpdateNoNotes => 'Без описания изменений.';

  @override
  String get appUpdateCancelDownload => 'Отменить';

  @override
  String get appUpdateInstall => 'Установить';

  @override
  String get appUpdateRetryInstall => 'Повторить установку';

  @override
  String get appUpdateRestart => 'Перезапустить';

  @override
  String get appUpdateRestartAndUpdate => 'Перезапустить и обновить';

  @override
  String get appUpdateDownloading => 'Скачивание';

  @override
  String get appUpdateRetry => 'Повторить';

  @override
  String get appUpdateDownloadAgain => 'Скачать заново';

  @override
  String appUpdateProgress(String received, String total) {
    return '$received / $total';
  }

  @override
  String get appUpdateFailureNetwork =>
      'Не удалось скачать обновление. Ошибка сети.';

  @override
  String get appUpdateFailureInvalidFile => 'Файл повреждён';

  @override
  String get appUpdateFailureStorage => 'Не хватает места для обновления.';

  @override
  String get appUpdateFailureInstall => 'Не удалось открыть установщик.';

  @override
  String get appUpdateFailurePermission =>
      'Разрешите Iris устанавливать приложения в настройках Android.';

  @override
  String get charactersTitle => 'Персонажи';

  @override
  String charactersAll(int count) {
    return 'Все $count';
  }

  @override
  String get charactersMainTitle => 'Главные';

  @override
  String get charactersSupportingTitle => 'Второстепенные';

  @override
  String get charactersLoading => 'Загрузка персонажей';

  @override
  String get charactersLoadError => 'Не удалось загрузить персонажей.';

  @override
  String get charactersEmpty => 'Персонажи не указаны.';

  @override
  String get characterLoading => 'Загрузка персонажа';

  @override
  String get characterLoadError => 'Не удалось загрузить персонажа.';

  @override
  String get characterDescriptionTitle => 'О персонаже';

  @override
  String get characterAnimeTitle => 'Аниме';

  @override
  String get characterFactJapanese => 'По-японски';

  @override
  String get characterFactAltNames => 'Другие имена';

  @override
  String get characterRoleMain => 'Главная роль';

  @override
  String get characterRoleSupporting => 'Второстепенная роль';

  @override
  String get animeDetailsFactNextEpisode => 'Следующая';

  @override
  String get animeDetailsFactStudio => 'Студия';

  @override
  String get animeDetailsFactGenres => 'Жанры';

  @override
  String get animeDetailsFactRating => 'Рейтинг';

  @override
  String playerMarked(int episode) {
    return 'Серия $episode отмечена';
  }

  @override
  String playerMarkOffer(int episode) {
    return 'Отметить серию $episode на Шикимори?';
  }

  @override
  String get playerMarkAction => 'Отметить';

  @override
  String playerMarkFailed(int episode) {
    return 'Не удалось отметить серию $episode';
  }

  @override
  String get playerUnmarkFailed => 'Не удалось отменить';

  @override
  String get playerRestoreFailed => 'Не удалось вернуть';

  @override
  String playerMarkUnset(int episode) {
    return 'Серия $episode не отмечена';
  }

  @override
  String playerMarkWaiting(int episode) {
    return 'Серия $episode · ждёт отправки';
  }

  @override
  String playerMarkSyncFailed(int episode) {
    return 'Серия $episode · ошибка синхронизации';
  }

  @override
  String get playerMarkConflict => 'Запись уже изменилась на Шикимори';

  @override
  String get playerMarkSaving => 'Сохранение';

  @override
  String get playerUnmarkSaving => 'Отмена отметки';

  @override
  String get playerRestoreSaving => 'Возврат отметки';

  @override
  String get playerMarkShortMarked => 'Отмечена';

  @override
  String get playerMarkShortUnset => 'Не отмечена';

  @override
  String get playerMarkShortFailed => 'Ошибка отметки';

  @override
  String get playerMarkShortWaiting => 'Ждёт отправки';

  @override
  String get playerMarkShortSyncFailed => 'Ошибка синхронизации';

  @override
  String get playerMarkShortConflict => 'Запись изменилась';

  @override
  String get playerMarkShortRestoreSaving => 'Возврат';

  @override
  String get playerMarkRestore => 'Вернуть';

  @override
  String get playerMarkExpand => 'Показать действия с отметкой';

  @override
  String get playerMarkCollapse => 'Скрыть действия с отметкой';

  @override
  String get playerMarkDismiss => 'Закрыть';

  @override
  String playerMarkPreviously(String status) {
    return 'Ранее: $status';
  }

  @override
  String playerMarkNextPending(int current, int total) {
    return 'Следующая отметка: $current из $total';
  }

  @override
  String get profileSigningInHint =>
      'Завершите вход в браузере. Если вернуться раньше, он прервётся.';

  @override
  String get profileSignInPortBusy =>
      'Порт 43821 для входа занят другой программой.';

  @override
  String get profileListTab => 'Список';

  @override
  String get profileListEmptyHint => 'Статус выбирается на странице аниме.';

  @override
  String profileListProgress(int watched, int total) {
    return '$watched из $total сер.';
  }

  @override
  String profileListWatched(int watched) {
    return '$watched сер.';
  }

  @override
  String get commonBrowseCatalog => 'Открыть каталог';

  @override
  String get savedTorrentsAddConfirm => 'Добавить';

  @override
  String get savedTorrentsAdding => 'Добавление раздачи';

  @override
  String get savedTorrentsSaveFailed => 'Не удалось сохранить раздачу.';

  @override
  String get savedTorrentsDeleted => 'Раздача удалена';

  @override
  String savedTorrentsEpisodeWatched(int number) {
    return 'Серия $number просмотрена';
  }

  @override
  String savedTorrentsFileWatched(String fileName) {
    return 'Просмотрено: $fileName';
  }

  @override
  String get commonUndo => 'Отменить';

  @override
  String get userRateLoading => 'Загрузка списка';

  @override
  String get downloadNoPeers => 'пока нет пиров';

  @override
  String get downloadTimeLeftUnderMinute => 'осталось < 1 мин';

  @override
  String downloadTimeLeftMinutes(int minutes) {
    return 'осталось ~$minutes мин';
  }

  @override
  String downloadTimeLeftHours(int hours, int minutes) {
    return 'осталось ~$hours ч $minutes мин';
  }

  @override
  String get downloadFailedNoSpace => 'Нет места на диске';

  @override
  String get downloadFailedNoAccess => 'Нет доступа к папке загрузок';

  @override
  String get downloadFailedFileMissing => 'Файл не найден';

  @override
  String get downloadFailedCouldNotStart => 'Не удалось начать загрузку';

  @override
  String get downloadSelectionEpisodeTitle => 'Скачать серии';

  @override
  String get downloadFailedConnectionLost => 'Потеряно соединение с сервером';

  @override
  String get downloadFailedNotDownloadable => 'Доступно только онлайн';

  @override
  String downloadDeleteProgressLost(String size) {
    return 'Скачанные $size будут удалены.';
  }

  @override
  String downloadAnnounceCompleted(String name) {
    return 'Скачано: $name';
  }

  @override
  String downloadAnnounceFailed(String name) {
    return 'Ошибка загрузки: $name';
  }

  @override
  String get watchSourcesMineSection => 'Мои';

  @override
  String get watchSourcesAddOwnTorrent => 'Добавить свою раздачу';

  @override
  String savedTorrentsAddWithShortcut(String shortcut) {
    return 'Добавить раздачу ($shortcut)';
  }

  @override
  String get savedTorrentsOr => 'или';

  @override
  String get savedTorrentsChooseFile => 'Выбрать файл .torrent';

  @override
  String get savedTorrentsNotTorrentFile => 'Это не торрент-файл.';

  @override
  String get savedTorrentsFileTooLarge => 'Файл слишком большой для торрента.';

  @override
  String get savedTorrentsFileReadFailed => 'Не удалось прочитать файл.';

  @override
  String get savedTorrentsFromFile => 'из файла';

  @override
  String get savedTorrentsFromLink => 'по ссылке';

  @override
  String savedTorrentsFileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count файла',
      many: '$count файлов',
      few: '$count файла',
      one: '$count файл',
    );
    return '$_temp0';
  }

  @override
  String get savedTorrentsClearDraft => 'Убрать';

  @override
  String downloadTitleReady(int ready, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'серий',
      one: 'серии',
    );
    return '$ready из $total $_temp0 готово';
  }

  @override
  String get downloadTitleEmpty => 'Скачанных серий этого аниме нет.';

  @override
  String downloadEpisodeLabel(String number) {
    return 'Серия $number';
  }

  @override
  String get downloadOpenAnime => 'Перейти к аниме';

  @override
  String get downloadStatusDetails => 'Состояние загрузки';

  @override
  String downloadTitleEpisodeCount(int ready, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'серий',
      one: 'серии',
    );
    return '$ready из $total $_temp0';
  }

  @override
  String get downloadDeleteAll => 'Удалить все серии';

  @override
  String get animeListDemographicsSectionTitle => 'Аудитория';

  @override
  String get animeListThemesSectionTitle => 'Темы';

  @override
  String get animeListCollapse => 'Свернуть';

  @override
  String get animeListShowResults => 'Показать';

  @override
  String animeListShowCount(String count) {
    return 'Показать $count';
  }

  @override
  String get searchRecentEmpty => 'Недавних запросов пока нет.';

  @override
  String get searchRecentClear => 'Очистить историю';

  @override
  String searchRecentRemove(String query) {
    return 'Удалить запрос «$query»';
  }

  @override
  String animeListRemoveFilter(String filter) {
    return 'Снять фильтр «$filter»';
  }

  @override
  String get animeListFiltersTitle => 'Фильтры';

  @override
  String get animeListResetFilters => 'Сбросить фильтры';

  @override
  String animeListShowMore(int count) {
    return 'Ещё $count';
  }

  @override
  String get downloadSelect => 'Выбрать';

  @override
  String downloadDeleteSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count',
      zero: 'Удалить',
    );
    return '$_temp0';
  }

  @override
  String downloadDeleteSelectedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count загрузки?',
      many: 'Удалить $count загрузок?',
      few: 'Удалить $count загрузки?',
      one: 'Удалить $count загрузку?',
    );
    return '$_temp0';
  }

  @override
  String downloadDeleteSpace(String size) {
    return 'Освободится около $size.';
  }

  @override
  String get downloadDeleteUnfinished =>
      'Незавершённые загрузки будут отменены.';

  @override
  String get downloadDeleting => 'Удаление';

  @override
  String downloadDeleteSelectionFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Не удалось удалить $count загрузки.',
      many: 'Не удалось удалить $count загрузок.',
      few: 'Не удалось удалить $count загрузки.',
      one: 'Не удалось удалить $count загрузку.',
    );
    return '$_temp0';
  }

  @override
  String get downloadSelectEpisodes => 'Выберите серии';

  @override
  String get downloadSelectFiles => 'Выберите файлы';

  @override
  String get downloadSelectAll => 'Выбрать все';

  @override
  String get downloadDeselectAll => 'Снять выбор';

  @override
  String playerSourceSelectedCount(int count) {
    return 'Выбрано $count';
  }

  @override
  String playerSourceNextEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Следующие $count серии',
      many: 'Следующие $count серий',
      few: 'Следующие $count серии',
      one: 'Следующая серия',
    );
    return '$_temp0';
  }

  @override
  String playerSourceNextFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Следующие $count файла',
      many: 'Следующие $count файлов',
      few: 'Следующие $count файла',
      one: 'Следующий файл',
    );
    return '$_temp0';
  }

  @override
  String get playerSourceAllUnwatched => 'Непросмотренные';

  @override
  String get playerSourceDownloadQuality => 'Качество скачивания';

  @override
  String get playerSourceDownloaded => 'Скачано';

  @override
  String playerSourceDownloadedCount(int count) {
    return 'Скачано $count';
  }

  @override
  String get playerSourceQueueFailed => 'Не удалось добавить в очередь.';

  @override
  String get playerSourceUnwatched => 'Не просмотрено';

  @override
  String playerSourceEpisodeLabel(String number) {
    return 'Серия $number';
  }

  @override
  String playerSourceFileLabel(String number) {
    return 'Файл $number';
  }

  @override
  String get playerEpisodeFiller => 'Филлер';

  @override
  String get playerEpisodeRecap => 'Рекап';

  @override
  String downloadSelectedEpisodes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Скачать $count серии',
      many: 'Скачать $count серий',
      few: 'Скачать $count серии',
      one: 'Скачать $count серию',
      zero: 'Скачать',
    );
    return '$_temp0';
  }

  @override
  String downloadSelectedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Скачать $count файла',
      many: 'Скачать $count файлов',
      few: 'Скачать $count файла',
      one: 'Скачать $count файл',
      zero: 'Скачать',
    );
    return '$_temp0';
  }

  @override
  String get downloadQueueTitle => 'Очередь загрузок';

  @override
  String downloadQueueCount(int count) {
    return 'Очередь · $count';
  }

  @override
  String get downloadNext => 'В начало очереди';

  @override
  String get downloadMore => 'Скачать ещё';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsShortcutTooltip => 'Настройки · Ctrl+,';

  @override
  String get settingsSectionAccounts => 'Аккаунты';

  @override
  String get settingsSectionPlayback => 'Воспроизведение';

  @override
  String get settingsSectionAppearance => 'Оформление';

  @override
  String get settingsSectionAbout => 'О приложении';

  @override
  String get settingsAccountSignedOut => 'Не подключён';

  @override
  String get settingsCheckingSession => 'Проверка сессии';

  @override
  String get settingsSigningIn => 'Вход';

  @override
  String get settingsAnimejoySignedIn => 'Подключён';

  @override
  String get settingsAnimejoyUnverified => 'Не удалось проверить сессию';

  @override
  String get settingsAnimejoyExpired => 'Сессия истекла. Войдите снова.';

  @override
  String get settingsAnimejoyVerify => 'Проверить';

  @override
  String get settingsAnimejoySignInTitle => 'Вход в AnimeJoy';

  @override
  String get settingsAnimejoyLoginLabel => 'Логин';

  @override
  String get settingsAnimejoyPasswordLabel => 'Пароль';

  @override
  String get settingsAnimejoyShowPassword => 'Показать пароль';

  @override
  String get settingsAnimejoyHidePassword => 'Скрыть пароль';

  @override
  String get settingsAnimejoyLoginRequired => 'Введите логин';

  @override
  String get settingsAnimejoyPasswordRequired => 'Введите пароль';

  @override
  String get settingsAnimejoyErrorInvalidCredentials =>
      'Неверный логин или пароль';

  @override
  String get settingsAnimejoyErrorNetwork => 'Нет ответа от AnimeJoy.';

  @override
  String get settingsAnimejoyErrorUnavailable => 'Вход сейчас недоступен';

  @override
  String get settingsDefaultAudioLabel => 'Аудио';

  @override
  String get settingsDefaultSubtitlesLabel => 'Субтитры';

  @override
  String get settingsTrackAuto => 'Авто';

  @override
  String get settingsAudioJapanese => 'Японский';

  @override
  String get settingsAudioRussian => 'Русский';

  @override
  String get settingsAudioEnglish => 'Английский';

  @override
  String get settingsSubtitlesRussian => 'Русские';

  @override
  String get settingsSubtitlesEnglish => 'Английские';

  @override
  String get settingsSubtitlesOff => 'Выкл';

  @override
  String get settingsThemeLabel => 'Тема';

  @override
  String get settingsThemeSystem => 'Системная';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsLanguageLabel => 'Язык';

  @override
  String get settingsLanguageSystem => 'Системный';

  @override
  String get settingsLanguageRussian => 'Русский';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsAnimeTitleLanguageLabel => 'Названия аниме';

  @override
  String get settingsAnimeTitleLanguageAuto => 'Авто';

  @override
  String get settingsAnimeTitleLanguageRussian => 'Русские';

  @override
  String get settingsAnimeTitleLanguageRomaji => 'Ромадзи';

  @override
  String get settingsAnimeTitleLanguageEnglish => 'Английские';

  @override
  String get settingsEpisodeListLayoutLabel => 'Вид серий';

  @override
  String get settingsEpisodeListLayoutAuto => 'Авто';

  @override
  String get settingsEpisodeListLayoutList => 'Список';

  @override
  String get settingsEpisodeListLayoutGrid => 'Сетка';

  @override
  String get settingsAppVersion => 'Версия';

  @override
  String get settingsAppVersionUnknown => 'Неизвестна';

  @override
  String get settingsCheckUpdates => 'Проверить';

  @override
  String get settingsUpdateChecking => 'Проверка';

  @override
  String get settingsUpdateUpToDate => 'Актуальная версия';

  @override
  String get settingsUpdateCheckFailed => 'Не удалось проверить';

  @override
  String get settingsUpdateOpen => 'Обновить';

  @override
  String get settingsUpdateOpenDetails => 'Подробнее';

  @override
  String get settingsUpdateAvailableHint => 'Доступно обновление';

  @override
  String get animeDetailsBackToDescriptionButton => 'К описанию';

  @override
  String get animeDetailsBackToSourcesButton => 'К источникам';
}
