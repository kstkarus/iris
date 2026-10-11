import 'package:path/path.dart' as path;

/// Extensions of the video formats the torrent engine streams. Audio-only
/// formats are deliberately left out.
const _videoFileExtensions = {
  'mkv',
  'mp4',
  'webm',
  'avi',
  'mov',
  'm4v',
  'ts',
  'm2ts',
  'flv',
  'wmv',
  'mpg',
  'mpeg',
};

/// Whether [extension] (without the dot, any case) names a video format.
bool isVideoExtension(String extension) {
  return _videoFileExtensions.contains(extension.toLowerCase());
}

/// The extension of the file [name], lowercased and without the dot; empty
/// when it has none.
String videoFileExtension(String name) {
  return path.extension(name).replaceFirst('.', '').toLowerCase();
}

/// Whether the file [name] ends in a video extension.
bool isVideoFileName(String name) {
  return isVideoExtension(videoFileExtension(name));
}
