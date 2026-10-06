final _extension = RegExp(r'\.[A-Za-z0-9]{1,5}$');

/// A file name as viewers expect to read it: no folders, no extension
/// (`Season 1/Death Note 15.mkv` -> `Death Note 15`).
String fileDisplayName(String fileName) {
  final baseName = fileName.split(RegExp(r'[\\/]')).last;
  final withoutExtension = baseName.replaceFirst(_extension, '').trim();
  return withoutExtension.isEmpty ? baseName : withoutExtension;
}
