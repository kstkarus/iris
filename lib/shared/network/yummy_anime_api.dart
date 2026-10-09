/// yummy_anime's public API; no key needed.
/// Docs: https://yummy-anime.ru/api/swagger
abstract final class YummyAnimeApi {
  static const baseUrl = 'https://api.yani.tv';

  /// Anime whose names match `q`; each with its Shikimori id.
  static const searchPath = '/anime';

  /// Every video of an anime: one per episode, dub and player.
  static String videosPath(int animeId) => '/anime/$animeId/videos';
}
