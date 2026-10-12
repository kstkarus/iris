import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/shared/utils/file_display_name.dart';

/// The number a list shows for [file] at [position] in its source: the
/// episode's own ("04", "12.5"), else its place.
String episodeNumberLabel(PlayerVideoFile file, int position) {
  return file.numberLabel ?? '${position + 1}'.padLeft(2, '0');
}

final _bracketGroups = RegExp(r'\[[^\]]*\]|\([^)]*\)');
final _leadingNumber = RegExp(r'^[\s\d._\-–—:#]+');
final _trailingSeparators = RegExp(r'[\s._\-–—:#]+$');
final _letter = RegExp(r'\p{L}', unicode: true);

/// Each file's own episode name, where its name says more than the series
/// and the number every file shares: `Frieren - 11 - The Hero's Party`
/// gives `The Hero's Party`, `Death Note 19` gives nothing.
Map<int, String> distinctEpisodeNames(List<PlayerVideoFile> files) {
  // An online release names its episodes itself.
  if (files.any((file) => file.title.isNotEmpty)) {
    return {
      for (final file in files)
        if (file.title.isNotEmpty) file.index: file.title,
    };
  }
  if (files.length < 2) return const {};
  final names = [
    for (final file in files)
      fileDisplayName(
        file.name,
      ).replaceAll(_bracketGroups, ' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
  ];
  final prefix = _commonPrefixLength(names);
  final suffix = _commonSuffixLength(names, prefix);
  return {
    for (final (position, file) in files.indexed)
      file.index: ?_ownName(names[position], prefix, suffix),
  };
}

String? _ownName(String name, int prefix, int suffix) {
  final end = name.length - suffix;
  if (end <= prefix) return null;
  final own = name
      .substring(prefix, end)
      .replaceFirst(_leadingNumber, '')
      .replaceFirst(_trailingSeparators, '')
      .trim();
  return _letter.hasMatch(own) ? own : null;
}

int _commonPrefixLength(List<String> names) {
  var length = names.first.length;
  for (final name in names.skip(1)) {
    var common = 0;
    while (common < length &&
        common < name.length &&
        name.codeUnitAt(common) == names.first.codeUnitAt(common)) {
      common++;
    }
    length = common;
  }
  return length;
}

/// The common ending, not overlapping the common start.
int _commonSuffixLength(List<String> names, int prefix) {
  final first = names.first;
  var length = first.length - prefix;
  for (final name in names) {
    length = length.clamp(0, name.length - prefix);
    var common = 0;
    while (common < length &&
        name.codeUnitAt(name.length - 1 - common) ==
            first.codeUnitAt(first.length - 1 - common)) {
      common++;
    }
    length = common;
  }
  return length;
}

/// Whether [name] says nothing but the [number] beside it: an online
/// episode without a title is named by its number, a torrent file may be
/// just `01.mkv`.
bool nameIsJustNumber(String name, String number) {
  final named = num.tryParse(name.trim());
  return named != null && named == num.tryParse(number);
}
