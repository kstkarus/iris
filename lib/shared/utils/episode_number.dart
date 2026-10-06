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
  for (final pattern in [
    _seasonEpisode,
    _episodeWord,
    _japanese,
    _dashNumber,
    _bracketNumber,
    _bareNumber,
    _trailingNumber,
  ]) {
    for (final match in pattern.allMatches(name)) {
      final number = int.parse(match.group(1)!);
      if (_isEpisode(number)) return number;
    }
  }
  return null;
}

bool _isEpisode(int number) {
  final isYear = number >= 1900 && number < 2100;
  return number > 0 && !isYear && !_resolutions.contains(number);
}
