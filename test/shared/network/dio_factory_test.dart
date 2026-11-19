import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/dio_factory.dart';
import 'package:iris/shared/network/shikimori_auth_interceptor.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/network/shikimori_oauth_config.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_secure_storage.dart';

void main() {
  test('a slow token renewal still limits the dispatch rate', () {
    fakeAsync((fake) {
      final now = fake.getClock(DateTime.utc(2026, 11, 19)).now;
      final session = ShikimoriSessionStore(FakeSecureStorage());
      unawaited(
        session.write(
          ShikimoriTokens(
            accessToken: 'old',
            refreshToken: 'refresh',
            expiresAt: now(),
          ),
        ),
      );
      final oauthReply = Completer<FakeReply>();
      final oauthDio = fakeDio((_) => oauthReply.future);
      final dispatches = <Duration>[];
      final dio =
          createShikimoriDio(
              session: session,
              oauth: ShikimoriOAuthClient(
                dio: oauthDio,
                config: const ShikimoriOAuthConfig(
                  clientId: 'id',
                  clientSecret: 's',
                ),
                now: now,
              ),
              now: now,
              wait: Future<void>.delayed,
            )
            ..httpClientAdapter = FakeHttpAdapter((_) {
              dispatches.add(fake.elapsed);
              return const FakeReply(200);
            });
      for (var i = 0; i < 6; i++) {
        unawaited(dio.get<dynamic>('/api/animes/$i'));
      }

      fake.elapse(const Duration(seconds: 2));
      expect(dispatches, isEmpty);
      oauthReply.complete(
        const FakeReply(200, {
          'access_token': 'new',
          'refresh_token': 'refresh-new',
          'expires_in': 3600,
        }),
      );
      fake.elapse(Duration.zero);
      expect(dispatches, List.filled(5, const Duration(seconds: 2)));

      fake.elapse(const Duration(seconds: 1));
      expect(dispatches, hasLength(6));
      expect(dispatches.last, const Duration(seconds: 3));
      dio.close(force: true);
      oauthDio.close(force: true);
    });
  });

  test(
    'factory retries a refused request without a signed-out token',
    () async {
      final session = ShikimoriSessionStore(FakeSecureStorage());
      await session.write(
        ShikimoriTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      final sent = <Object?>[];
      final adapter = FakeHttpAdapter((options) async {
        sent.add(options.headers['Authorization']);
        if (sent.length == 1) {
          await session.clear();
          return const FakeReply(429, {}, {
            'retry-after': ['0'],
          });
        }
        return const FakeReply(200);
      });
      final dio = createShikimoriDio(
        session: session,
        oauth: ShikimoriOAuthClient(
          dio: createShikimoriOAuthDio(),
          config: const ShikimoriOAuthConfig(clientId: 'id', clientSecret: 's'),
        ),
      )..httpClientAdapter = adapter;

      await dio.get<dynamic>('/api/animes');

      expect(sent, ['Bearer access', null]);
    },
  );

  test(
    'factory cancels a queued account write when signing out during rate-limit wait',
    () async {
      var now = DateTime.utc(2026, 11, 19, 12);
      final session = ShikimoriSessionStore(FakeSecureStorage());
      await session.write(
        ShikimoriTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
          expiresAt: now.add(const Duration(days: 1)),
        ),
      );
      final generation = session.generation;
      final methods = <String>[];
      final waits = <Duration>[];
      final adapter = FakeHttpAdapter((options) {
        methods.add(options.method);
        return const FakeReply(200);
      });
      final dio = createShikimoriDio(
        session: session,
        oauth: ShikimoriOAuthClient(
          dio: createShikimoriOAuthDio(),
          config: const ShikimoriOAuthConfig(clientId: 'id', clientSecret: 's'),
        ),
        now: () => now,
        wait: (delay) async {
          waits.add(delay);
          now = now.add(delay);
          await session.clear();
        },
      )..httpClientAdapter = adapter;

      // Fill the 5 requests/second window so the write must wait.
      for (var i = 0; i < 5; i++) {
        await dio.get<dynamic>('/api/animes');
      }

      await expectLater(
        dio.patch<dynamic>(
          '/api/v2/user_rates/1',
          options: Options(
            extra: {ShikimoriAuthInterceptor.sessionGenerationKey: generation},
          ),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );

      expect(waits, [const Duration(seconds: 1)]);
      expect(methods, List.filled(5, 'GET'));
    },
  );
}
