import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;

import 'package:iris/shared/utils/desktop_platform.dart';

/// Asks the user for a `.torrent` file; its bytes, or null when cancelled.
typedef TorrentFilePicker = Future<Uint8List?> Function();

const _androidPicker = MethodChannel('iris/torrent_file_picker');

/// Upper bound on a `.torrent` file read into memory. Real torrent files are
/// typically tens of kilobytes (even huge multi-season packs stay well below
/// 10 MiB); rejecting larger files prevents accidentally picking a video from
/// exhausting memory on phones.
const maxTorrentFileBytes = 10 * 1024 * 1024;

/// Thrown when the picked file exceeds [maxTorrentFileBytes].
class TorrentFileTooLargeException implements Exception {
  const TorrentFileTooLargeException();
}

/// The system's file picker. Desktops show `.torrent` files only; phones
/// often do not know the type and would grey such files out, so they offer
/// any file and the app reads at most [maxTorrentFileBytes] of it.
Future<Uint8List?> pickTorrentFile() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    // file_selector_android reads the whole file before returning an XFile.
    try {
      return await _androidPicker.invokeMethod<Uint8List>(
        'pickTorrentFile',
        maxTorrentFileBytes,
      );
    } on PlatformException catch (error) {
      if (error.code == 'file_too_large') {
        throw const TorrentFileTooLargeException();
      }
      rethrow;
    }
  }
  final file = await openFile(
    acceptedTypeGroups: [
      if (isDesktopPlatform)
        const XTypeGroup(
          label: 'Torrent',
          extensions: ['torrent'],
          uniformTypeIdentifiers: ['public.data'],
        ),
    ],
  );
  if (file == null) return null;
  return readTorrentFileBytes(file);
}

/// Reads [file] up to [maxBytes], throwing [TorrentFileTooLargeException]
/// without loading oversized files into memory.
Future<Uint8List> readTorrentFileBytes(
  XFile file, {
  int maxBytes = maxTorrentFileBytes,
}) async {
  try {
    final length = await file.length();
    if (length > maxBytes) throw const TorrentFileTooLargeException();
  } on UnsupportedError {
    // Fall back to the streaming limit below.
  }
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead(0, maxBytes + 1)) {
    if (builder.length + chunk.length > maxBytes) {
      throw const TorrentFileTooLargeException();
    }
    builder.add(chunk);
  }
  return builder.takeBytes();
}
