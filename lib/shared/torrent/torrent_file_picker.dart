import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'package:iris/shared/utils/desktop_platform.dart';

/// Asks the user for a `.torrent` file; its bytes, or null when cancelled.
typedef TorrentFilePicker = Future<Uint8List?> Function();

/// The system's file picker. Desktops show `.torrent` files only; phones
/// often do not know the type and would grey such files out, so they offer
/// any file and the app reads it.
Future<Uint8List?> pickTorrentFile() async {
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
  return file?.readAsBytes();
}
