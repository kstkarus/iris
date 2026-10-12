import 'package:iris/features/online_sources/domain/repositories/online_quality_preferences.dart';

/// Keeps the quality choices in memory and records what was set.
class MemoryOnlineQualityPreferences implements OnlineQualityPreferences {
  MemoryOnlineQualityPreferences({this.watching, this.downloading});

  @override
  int? watching;

  @override
  int? downloading;

  @override
  Future<void> setWatching(int? height) async => watching = height;

  @override
  Future<void> setDownloading(int? height) async => downloading = height;
}
