import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';

String redactMagnet(String magnet) {
  if (magnet.length <= 32) {
    return magnet;
  }

  final prefix = magnet.substring(0, 20);
  final suffix = magnet.substring(magnet.length - 8);
  return '$prefix...$suffix';
}

String summarizeTorrentFiles(List<TorrentFileDescriptor> files) {
  if (files.isEmpty) {
    return 'no files';
  }

  return files
      .map((file) {
        return '[${file.index}] ${file.name} | size=${file.size} | streamable=${file.isStreamable}';
      })
      .join(' || ');
}

String formatBytesHex(List<int> bytes) {
  if (bytes.isEmpty) {
    return 'empty';
  }

  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(' ');
}
