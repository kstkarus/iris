import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/shared/utils/equality.dart';

class PreparedDownloadSource {
  const PreparedDownloadSource({
    required this.sourceToken,
    required this.files,
    this.qualities = const [],
  });

  final String sourceToken;
  final List<DownloadableFile> files;

  /// The picture heights an online release can be loaded in, tallest
  /// first; empty for a torrent, whose files come as they are.
  final List<int> qualities;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PreparedDownloadSource &&
        other.sourceToken == sourceToken &&
        sameList(other.files, files) &&
        sameList(other.qualities, qualities);
  }

  @override
  int get hashCode => Object.hash(
    sourceToken,
    Object.hashAll(files),
    Object.hashAll(qualities),
  );
}
