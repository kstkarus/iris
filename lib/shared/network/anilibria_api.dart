/// AniLibria's public API (now served as Aniliberty); no key needed.
/// Docs: https://aniliberty.top/api/docs/v1
abstract final class AnilibriaApi {
  static const baseUrl = 'https://aniliberty.top/api/v1';

  /// Releases whose names match a query; each with its Shikimori id.
  static const searchPath = '/app/search/releases';

  /// A release with its episodes.
  static String releasePath(int releaseId) => '/anime/releases/$releaseId';

  /// One episode, with stream links issued afresh.
  static String episodePath(String episodeId) =>
      '/anime/releases/episodes/$episodeId';
}
