import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:dio/dio.dart';

/// At most [requests] in any [window].
class RateLimit {
  const RateLimit(this.requests, this.window);

  final int requests;
  final Duration window;
}

/// Keeps requests within an API's published limits by holding each one
/// until it fits, instead of letting the server refuse it. A refusal that
/// happens anyway (429, e.g. another device on the same address) is
/// retried once after the server's Retry-After.
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor({
    required Dio dio,
    required List<RateLimit> limits,
    DateTime Function()? now,
    Future<void> Function(Duration)? wait,
  }) : _dio = dio,
       _limits = limits,
       _now = now ?? DateTime.now,
       _wait = wait ?? Future<void>.delayed;

  final Dio _dio;
  final List<RateLimit> _limits;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;

  /// Start times of the latest requests, oldest first, as many as the
  /// largest limit counts.
  final _starts = Queue<DateTime>();

  static const _retriedKey = 'rateLimitRetried';
  static const _defaultRetryAfter = Duration(seconds: 1);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final delay = _reserve();
    if (delay > Duration.zero) await _wait(delay);
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 429 || options.extra[_retriedKey] == true) {
      handler.next(err);
      return;
    }
    await _wait(_retryAfter(err.response!) ?? _defaultRetryAfter);
    try {
      options.extra[_retriedKey] = true;
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Takes the earliest start that keeps every limit, synchronously, so
  /// requests issued together queue up in order.
  Duration _reserve() {
    final now = _now();
    var start = now;
    for (final limit in _limits) {
      if (_starts.length < limit.requests) continue;
      final blocking = _starts.elementAt(_starts.length - limit.requests);
      final free = blocking.add(limit.window);
      if (free.isAfter(start)) start = free;
    }
    _starts.addLast(start);
    final keep = _limits.map((limit) => limit.requests).reduce(math.max);
    while (_starts.length > keep) {
      _starts.removeFirst();
    }
    return start.difference(now);
  }

  static Duration? _retryAfter(Response<dynamic> response) {
    final seconds = int.tryParse(response.headers.value('retry-after') ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}
