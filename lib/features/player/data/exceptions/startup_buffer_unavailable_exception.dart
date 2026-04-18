import 'package:iris/features/player/data/models/playback_launch_progress_model.dart';

class StartupBufferUnavailableException implements Exception {
  const StartupBufferUnavailableException({required this.progress});

  final PlaybackLaunchProgressModel progress;
}
