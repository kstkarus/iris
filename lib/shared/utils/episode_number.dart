import 'package:iris/shared/utils/file_display_name.dart';

final _seasonEpisode = RegExp(
  r'\bS\d{1,2}[ ._-]?E(\d{1,4})\b',
  caseSensitive: false,
);
final _episodeWord = RegExp(
  r'(?:\bepisode|\bep|серия)[ ._-]*(\d{1,4})\b',
  caseSensitive: false,
);
final _japanese = RegExp(r'第(\d{1,4})[話话集]');
// The fansub convention: `[Group] Title - 05 (1080p)`.
final _dashNumber = RegExp(r'\s-\s(\d{1,4})(?:v\d)?(?=$|[\s.\[(])');
final _bracketNumber = RegExp(r'\[(\d{1,4})(?:v\d)?\]');
final _bareNumber = RegExp(r'^(\d{1,4})(?:v\d)?$');
// `Death Note 15`.
final _trailingNumber = RegExp(r'\s(\d{1,4})(?:v\d)?$');

const _resolutions = {480, 540, 576, 720, 1080, 1440, 2160};

/// The episode number in a release's file name, or null when there is no
/// recognisable one.
int? episodeNumberFromFileName(String fileName) {
  final name = fileDisplayName(fileName);
  // Named as an episode: 1080 is episode 1080 of a long series.
  for (final pattern in [_seasonEpisode, _episodeWord, _japanese]) {
    for (final match in pattern.allMatches(name)) {
      final number = int.parse(match.group(1)!);
      if (number > 0) return number;
    }
  }
  // `Title - 1080 (1080p)`, but `Film - 2019` is the year.
  for (final match in _dashNumber.allMatches(name)) {
    final number = int.parse(match.group(1)!);
    if (number > 0 && !_isYear(number)) return number;
  }
  // A bare number may as well be the resolution or the year.
  for (final pattern in [_bracketNumber, _bareNumber, _trailingNumber]) {
    for (final match in pattern.allMatches(name)) {
      final number = int.parse(match.group(1)!);
      if (_isEpisode(number)) return number;
    }
  }
  return null;
}

bool _isEpisode(int number) =>
    number > 0 && !_isYear(number) && !_resolutions.contains(number);

bool _isYear(int number) => number >= 1900 && number < 2100;
