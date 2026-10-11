import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/models/player_chrome_mapper.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

AnimePlayerSource _source({
  String animeTitle = 'Frieren',
  int fileIndex = 1,
  List<PlayerVideoFile> files = const [],
}) => AnimePlayerSource(
  animeId: '1',
  animeTitle: animeTitle,
  sourceTitle: '[Group] Frieren [1080p]',
  sessionId: '1',
  fileIndex: fileIndex,
  fileName: files.isEmpty ? 'Frieren 02.mkv' : files.first.name,
  files: files,
);

PlayerVideoFile _file(int index, String name) =>
    PlayerVideoFile(index: index, name: name, size: 1, extension: 'mkv');

void main() {
  test('puts the anime over the episode and adds only the total', () {
    final chrome = playerChromeFor(
      _l10n,
      _source(files: [_file(0, 'Frieren 01.mkv'), _file(1, 'Frieren 02.mkv')]),
      onBack: () {},
    );

    expect(chrome.overline, 'Frieren');
    expect(chrome.title, _l10n.playerEpisodeNumber(2));
    expect(chrome.titleDetail, _l10n.playerEpisodeOfTotal(2));
    expect(chrome.details, isNull);
    expect(
      chrome.episodesCaption,
      '[Group] Frieren [1080p] · ${_l10n.animeEpisodeCount('2', 2)}',
    );
  });

  test('gives the place when the number is not the place', () {
    final chrome = playerChromeFor(
      _l10n,
      _source(files: [_file(0, 'Frieren 11.mkv'), _file(1, 'Frieren 12.mkv')]),
      onBack: () {},
    );

    expect(chrome.title, _l10n.playerEpisodeNumber(12));
    expect(chrome.titleDetail, isNull);
    expect(chrome.details, _l10n.playerEpisodePosition(2, 2));
  });

  test('names a saved torrent by its release', () {
    final chrome = playerChromeFor(
      _l10n,
      _source(animeTitle: '[Group] Frieren [1080p]'),
      onBack: () {},
    );

    expect(chrome.overline, isNot('[Group] Frieren [1080p]'));
    expect(chrome.details, isNull);
  });
}
