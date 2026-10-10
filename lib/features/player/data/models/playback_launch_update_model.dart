import 'package:iris/features/player/data/models/prepared_playback_model.dart';

sealed class PlaybackLaunchUpdateModel {
  const PlaybackLaunchUpdateModel();
}

final class PlaybackLaunchReadyUpdateModel extends PlaybackLaunchUpdateModel {
  const PlaybackLaunchReadyUpdateModel(this.playback);

  final PreparedPlaybackModel playback;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlaybackLaunchReadyUpdateModel &&
        other.playback == playback;
  }

  @override
  int get hashCode => playback.hashCode;
}

final class PlaybackLaunchFailureUpdateModel extends PlaybackLaunchUpdateModel {
  const PlaybackLaunchFailureUpdateModel();

  @override
  bool operator ==(Object other) => other is PlaybackLaunchFailureUpdateModel;

  @override
  int get hashCode => runtimeType.hashCode;
}
