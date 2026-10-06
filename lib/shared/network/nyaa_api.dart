abstract final class NyaaApi {
  static const baseUrl = 'https://nyaaapi.onrender.com';
  static const searchPath = '/nyaa';

  /// Nyaa's anime section (releases, raws, AMVs); without it searches also
  /// return soundtracks and manga.
  static const animeCategory = 'anime';
}
