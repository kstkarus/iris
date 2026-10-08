import 'package:iris/shared/network/rate_limit_interceptor.dart';

abstract final class ShikimoriApi {
  static const baseUrl = 'https://shikimori.io';
  static const graphQlPath = '/api/graphql';

  /// Shikimori asks every client to name itself here (the OAuth
  /// application's name once there is one) and bans addresses that send
  /// browser-like or empty agents.
  static const userAgent = 'iris';

  /// The published limits: 5 requests a second and 90 a minute.
  static const rateLimits = [
    RateLimit(5, Duration(seconds: 1)),
    RateLimit(90, Duration(minutes: 1)),
  ];
}
