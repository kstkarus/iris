import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';

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
        _sameFiles(other.files, files);
  }

  @override
  int get hashCode => Object.hash(sourceToken, Object.hashAll(files));
}

bool _sameFiles(List<DownloadableFile> first, List<DownloadableFile> second) {
  if (first.length != second.length) {
    return false;
  }

  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      return false;
    }
  }

  return true;
}
