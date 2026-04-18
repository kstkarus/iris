import 'package:iris/features/player/data/models/torrent_file_descriptor.dart';

class PreparedPlayerSourceModel {
  const PreparedPlayerSourceModel({
    required this.sessionId,
    required this.files,
  });

  final String sessionId;
  final List<TorrentFileDescriptor> files;
}
