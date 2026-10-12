import 'package:iris/features/online_sources/domain/entities/online_release.dart';

/// Each episode's file index comes from its number alone, so every dub of
/// an anime files its progress (and its download) under the same index: 12
/// is 12, a special 12.5 is [_firstSpecial] + 1250. A number the release
/// repeats is its own oddity and keeps its place past both.
List<int> onlineEpisodeFileIndices(OnlineRelease release) {
  final used = <int>{};
  return [
    for (final (position, episode) in release.episodes.indexed)
      switch (_numberIndex(episode.number)) {
        final index? when used.add(index) => index,
        _ => _firstRepeat + position,
      },
  ];
}

const _firstSpecial = 100000;
const _firstRepeat = 300000;

int? _numberIndex(num number) {
  if (number < 0) return null;
  if (number % 1 == 0) return number.toInt();
  final hundredths = (number * 100).round();
  return hundredths < _firstRepeat - _firstSpecial
      ? _firstSpecial + hundredths
      : null;
}

/// What watch history and downloads keep as the "file name":
/// `04 «Пристанище душ»`.
String onlineEpisodeFileName(num number, String title) {
  final digits = number % 1 == 0
      ? number.toInt().toString().padLeft(2, '0')
      : '$number';
  return title.isEmpty ? digits : '$digits $title';
}
