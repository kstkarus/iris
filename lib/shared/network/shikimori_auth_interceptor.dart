import 'package:dio/dio.dart';

import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

/// Sends the signed-in account's token with Shikimori requests and renews
/// it when it runs out (it lasts a day).
///
/// Requests that find the token stale together share one renewal. A token
/// Shikimori refuses to renew ends the session; a renewal that fails for
/// the network keeps it, and the request goes as it is.
///
/// Not a QueuedInterceptor: a repeated request refused again would wait
/// in the error queue behind its own first refusal.
class ShikimoriAuthInterceptor extends Interceptor {
  ShikimoriAuthInterceptor({
    required Dio dio,
    required ShikimoriSessionStore store,
    required ShikimoriOAuthClient oauth,
    DateTime Function()? now,
  }) : _dio = dio,
       _store = store,
       _oauth = oauth,
       _now = now ?? DateTime.now;

  /// Renewed this long before it runs out, so it does not lapse in flight.
  static const refreshMargin = Duration(minutes: 1);

  static const _retriedKey = 'authRetried';
  static const _header = 'Authorization';

  final Dio _dio;
  final ShikimoriSessionStore _store;
  final ShikimoriOAuthClient _oauth;
  final DateTime Function() _now;

  Future<ShikimoriTokens?>? _renewal;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    var tokens = await _store.read();
    if (tokens != null && _isStale(tokens)) {
      tokens = await _renew(tokens) ?? await _store.read();
    }
    if (tokens != null) {
      options.headers[_header] = _bearer(tokens);
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final sent = options.headers[_header];
    if (err.response?.statusCode != 401 ||
        sent == null ||
        options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    var tokens = await _store.read();
    // Another request may have renewed it while this one was out.
    if (tokens != null && _bearer(tokens) == sent) {
      tokens = await _renew(tokens);
    }
    if (tokens == null) {
      handler.next(err);
      return;
    }
    options
      ..extra[_retriedKey] = true
      ..headers[_header] = _bearer(tokens);
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isStale(ShikimoriTokens tokens) =>
      !_now().isBefore(tokens.expiresAt.subtract(refreshMargin));

  /// One renewal at a time; whoever asks meanwhile gets its result.
  Future<ShikimoriTokens?> _renew(ShikimoriTokens tokens) =>
      _renewal ??= _refresh(tokens).whenComplete(() => _renewal = null);

  Future<ShikimoriTokens?> _refresh(ShikimoriTokens tokens) async {
    try {
      final renewed = await _oauth.refresh(tokens.refreshToken);
      await _store.write(renewed);
      return renewed;
    } on InvalidGrantException {
      await _store.expire();
      return null;
    } on Exception {
      return null;
    }
  }

  static String _bearer(ShikimoriTokens tokens) =>
      'Bearer ${tokens.accessToken}';
}
