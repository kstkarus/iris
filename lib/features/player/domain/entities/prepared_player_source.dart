import 'package:iris/features/player/domain/entities/player_video_file.dart';

class PreparedPlayerSource {
  const PreparedPlayerSource({required this.sessionId, required this.files});

  final String sessionId;
  final List<PlayerVideoFile> files;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PreparedPlayerSource &&
        other.sessionId == sessionId &&
        _listEquals(other.files, files);
  }

  @override
  int get hashCode => Object.hash(sessionId, Object.hashAll(files));
}

bool _listEquals(List<Object?> left, List<Object?> right) {
  if (identical(left, right)) {
    return true;
  }

  if (left.length != right.length) {
    return false;
  }

  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }

  return true;
}
