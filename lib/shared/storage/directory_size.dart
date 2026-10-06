import 'dart:io';

/// Sums the sizes of all files below [directory]; 0 when it does not exist.
Future<int> directorySize(Directory directory) async {
  if (!await directory.exists()) return 0;
  var total = 0;
  await for (final entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File) {
      try {
        total += await entity.length();
      } on FileSystemException {
        // A file may disappear while the size is being calculated.
      }
    }
  }
  return total;
}
