import 'package:iris/shared/network/rate_limit_interceptor.dart';

/// Tenrai v1 (Jikan v4-compatible): unofficial MyAnimeList REST API for
/// episode titles and filler/recap flags, keyed by MyAnimeList (= Shikimori)
/// anime id.
abstract final class TenraiApi {
  static const baseUrl = 'https://api.tenrai.org';

  static String episodesPath(String malId) => '/v1/anime/$malId/episodes';

  /// Tenrai published public limits: 4 requests/second, 120 requests/minute.
  static const rateLimits = [
    RateLimit(4, Duration(seconds: 1)),
    RateLimit(120, Duration(minutes: 1)),
  ];
}
