import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/rate_limit_interceptor.dart';
import 'package:iris/shared/network/shikimori_api.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late DateTime now;
  late List<Duration> waits;

  RateLimitInterceptor limiter(Dio dio) => RateLimitInterceptor(
    dio: dio,
    limits: ShikimoriApi.rateLimits,
    now: () => now,
    wait: (delay) async {
      waits.add(delay);
      now = now.add(delay);
    },
  );

  setUp(() {
    now = DateTime.utc(2026, 10, 7, 12);
    waits = [];
  });

  Future<void> request(RateLimitInterceptor interceptor) =>
      interceptor.onRequest(RequestOptions(), RequestInterceptorHandler());

  test(
    'holds the sixth request of a second until the second is over',
    () async {
      final interceptor = limiter(Dio());

      for (var index = 0; index < 5; index++) {
        await request(interceptor);
      }
      expect(waits, isEmpty);

      await request(interceptor);
      expect(waits, [const Duration(seconds: 1)]);
    },
  );

  test('keeps to 90 requests a minute', () async {
    final interceptor = limiter(Dio());

    for (var index = 0; index < 91; index++) {
      await request(interceptor);
    }

    // Five a second fill 90 in 17 seconds; the 91st waits for the first
    // to leave the minute.
    expect(now, DateTime.utc(2026, 10, 7, 12, 1));
  });

  test('requests spread over time pass without waiting', () async {
    final interceptor = limiter(Dio());

    for (var index = 0; index < 20; index++) {
      await request(interceptor);
      now = now.add(const Duration(milliseconds: 250));
    }

    expect(waits, isEmpty);
  });

  test('retries a refused request once after Retry-After', () async {
    final adapter = _answering([429, 200]);
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(limiter(dio));

    final response = await dio.get<dynamic>('https://example.org/api');

    expect(response.statusCode, 200);
    expect(adapter.requests.length, 2);
    expect(waits, contains(const Duration(seconds: 2)));
  });

  test('gives up after a second refusal', () async {
    final adapter = _answering([429, 429, 200]);
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(limiter(dio));

    await expectLater(
      dio.get<dynamic>('https://example.org/api'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status',
          429,
        ),
      ),
    );
    expect(adapter.requests.length, 2);
  });

  test('a Retry-After too long to wait fails at once', () async {
    final adapter = _answering([429, 200], retryAfter: '3600');
    final dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(limiter(dio));

    await expectLater(
      dio.get<dynamic>('https://example.org/api'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.requests.length, 1);
    expect(waits, isEmpty);
  });
}

/// Answers the requests in turn with [statuses]; a refusal asks to retry
/// after [retryAfter] seconds.
FakeHttpAdapter _answering(List<int> statuses, {String retryAfter = '2'}) {
  late final FakeHttpAdapter adapter;
  adapter = FakeHttpAdapter((_) {
    final status = statuses[adapter.requests.length - 1];
    return FakeReply(
      status,
      {'ok': status == 200},
      {
        if (status == 429) 'retry-after': [retryAfter],
      },
    );
  });
  return adapter;
}
