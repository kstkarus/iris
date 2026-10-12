/// Why a download stopped, in terms the user can act on.
enum DownloadFailure {
  /// The device ran out of space for the file.
  noSpace,

  /// The app may not write where downloads go.
  noAccess,

  /// A finished file is gone from the device.
  fileMissing,

  /// The torrent could not be started, usually for want of a connection.
  couldNotStart,

  /// An online episode's video server stopped answering; a retry picks up
  /// where it stopped.
  connectionLost,

  /// An online episode comes only in a form that cannot be loaded (DASH,
  /// encrypted HLS): it can only be watched online.
  notDownloadable,

  /// Anything else the torrent engine reported.
  other,
}

final _noSpace = RegExp(
  r'no space|not enough space|disk (is )?full|ENOSPC',
  caseSensitive: false,
);
final _noAccess = RegExp(
  r'permission denied|access is denied|EACCES|read-only file system',
  caseSensitive: false,
);

/// Reads the reason out of a stored [message]: the repository's own
/// messages and the engine's (POSIX and Windows wordings), whose text is
/// kept as it came.
DownloadFailure downloadFailureFrom(String? message) {
  final text = message ?? '';
  if (_noSpace.hasMatch(text)) return DownloadFailure.noSpace;
  if (_noAccess.hasMatch(text)) return DownloadFailure.noAccess;
  if (text == downloadFileMissingMessage) return DownloadFailure.fileMissing;
  if (text == downloadCouldNotStartMessage) {
    return DownloadFailure.couldNotStart;
  }
  if (text == downloadConnectionLostMessage) {
    return DownloadFailure.connectionLost;
  }
  if (text == downloadNotDownloadableMessage) {
    return DownloadFailure.notDownloadable;
  }
  return DownloadFailure.other;
}

/// Stored for a finished file that disappeared.
const downloadFileMissingMessage = 'Downloaded file is missing.';

/// Stored when the engine would not start the torrent.
const downloadCouldNotStartMessage = 'Unable to start the download.';

/// Stored when an online episode's server stopped answering.
const downloadConnectionLostMessage = 'The video server stopped answering.';

/// Stored when an online episode has no stream that can be loaded.
const downloadNotDownloadableMessage = 'The episode has no loadable stream.';
