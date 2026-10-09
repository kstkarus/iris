// An extension has a letter: `Frieren 12.5` keeps its `.5`.
final _extension = RegExp(r'\.(?=[A-Za-z0-9]{0,4}[A-Za-z])[A-Za-z0-9]{1,5}$');

/// A file name as viewers expect to read it: no folders, no extension
/// (`Season 1/Death Note 15.mkv` -> `Death Note 15`).
String fileDisplayName(String fileName) {
  final baseName = fileName.split(RegExp(r'[\\/]')).last;
  final withoutExtension = baseName.replaceFirst(_extension, '').trim();
  return withoutExtension.isEmpty ? baseName : withoutExtension;
}
