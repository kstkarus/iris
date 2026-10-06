import 'package:iris/features/player/data/models/playback_launch_progress_model.dart';
import 'package:iris/features/player/data/models/prepared_playback_model.dart';

enum PlaybackLaunchFailureModel { unableToStart, unableToPrepareStartupBuffer }

sealed class PlaybackLaunchUpdateModel {
  const PlaybackLaunchUpdateModel();
}

final class PlaybackLaunchProgressUpdateModel
    extends PlaybackLaunchUpdateModel {
  const PlaybackLaunchProgressUpdateModel(this.progress);

  final PlaybackLaunchProgressModel progress;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlaybackLaunchProgressUpdateModel &&
        other.progress == progress;
  }

  @override
  int get hashCode => progress.hashCode;
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
  const PlaybackLaunchFailureUpdateModel(this.failure);

  final PlaybackLaunchFailureModel failure;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlaybackLaunchFailureUpdateModel &&
        other.failure == failure;
  }

  @override
  int get hashCode => failure.hashCode;
}
