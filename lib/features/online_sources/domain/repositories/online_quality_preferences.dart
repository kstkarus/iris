/// The picture height wanted from video servers, kept apart for watching
/// (traffic, how soon it starts) and for downloading (room on the device).
/// Null is "Auto": the tallest there is.
abstract interface class OnlineQualityPreferences {
  int? get watching;

  Future<void> setWatching(int? height);

  int? get downloading;

  Future<void> setDownloading(int? height);
}
