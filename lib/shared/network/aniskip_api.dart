/// AniSkip: community-sourced opening/ending times, keyed by MyAnimeList
/// id and episode number.
abstract final class AniSkipApi {
  static const baseUrl = 'https://api.aniskip.com';

  static String skipTimesPath(String malId, int episode) =>
      '/v2/skip-times/$malId/$episode';

  static const skipTypes = ['op', 'ed', 'mixed-op', 'mixed-ed', 'recap'];
}
