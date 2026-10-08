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
