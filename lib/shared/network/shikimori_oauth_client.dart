import 'package:dio/dio.dart';

import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_api.dart';
import 'package:iris/shared/network/shikimori_oauth_config.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

/// Shikimori's OAuth endpoints: the page that asks the user, and the token
/// exchange behind it.
///
/// Its Dio (`createShikimoriOAuthDio`) sends forms, and must not carry the
/// auth interceptor, which calls [refresh].
class ShikimoriOAuthClient {
  ShikimoriOAuthClient({
    required Dio dio,
    required ShikimoriOAuthConfig config,
    DateTime Function()? now,
  }) : _dio = dio,
       _config = config,
       _now = now ?? DateTime.now;

  final Dio _dio;
  final ShikimoriOAuthConfig _config;
  final DateTime Function() _now;

  bool get isConfigured => _config.isConfigured;

  Uri authorizeUrl({required String state}) =>
      Uri.parse(
        ShikimoriApi.baseUrl + ShikimoriOAuthConfig.authorizePath,
      ).replace(
        queryParameters: {
          'client_id': _config.clientId,
          'redirect_uri': _config.redirectUri,
          'response_type': 'code',
          'scope': ShikimoriOAuthConfig.scope,
          'state': state,
        },
      );

  Future<ShikimoriTokens> exchangeCode(String code) => _requestTokens({
    'grant_type': 'authorization_code',
    'code': code,
    'redirect_uri': _config.redirectUri,
  });

  Future<ShikimoriTokens> refresh(String refreshToken) => _requestTokens({
    'grant_type': 'refresh_token',
    'refresh_token': refreshToken,
  });

  Future<ShikimoriTokens> _requestTokens(Map<String, String> grant) async {
    final requestedAt = _now();
    final Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        ShikimoriOAuthConfig.tokenPath,
        data: {
          ...grant,
          'client_id': _config.clientId,
          'client_secret': _config.clientSecret,
        },
      );
    } on DioException catch (error) {
      if (_isInvalidGrant(error.response)) {
        throw const InvalidGrantException('Shikimori refused the grant.');
      }
      throw mapDioException(error);
    }
    return _parseTokens(response.data, requestedAt);
  }

  static bool _isInvalidGrant(Response<dynamic>? response) {
    final data = response?.data;
    return data is Map && data['error'] == 'invalid_grant';
  }

  static ShikimoriTokens _parseTokens(Object? data, DateTime requestedAt) {
    if (data is! Map) {
      throw const RemoteResponseException('Token response is not an object.');
    }
    final access = data['access_token'];
    final refresh = data['refresh_token'];
    final expiresIn = data['expires_in'];
    if (access is! String || refresh is! String || expiresIn is! num) {
      throw const RemoteResponseException('Token response lacks a token.');
    }
    return ShikimoriTokens(
      accessToken: access,
      refreshToken: refresh,
      // Counted from before the request, so the app renews a little early
      // rather than a little late.
      expiresAt: requestedAt.add(Duration(seconds: expiresIn.toInt())),
    );
  }
}
