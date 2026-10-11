import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/shared/utils/equality.dart';

class PreparedDownloadSource {
  const PreparedDownloadSource({
    required this.sourceToken,
    required this.files,
  });

  final String sourceToken;
  final List<DownloadableFile> files;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PreparedDownloadSource &&
        other.sourceToken == sourceToken &&
        sameList(other.files, files);
  }

  @override
  int get hashCode => Object.hash(sourceToken, Object.hashAll(files));
}
