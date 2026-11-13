import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/dio_factory.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/network/shikimori_oauth_config.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_secure_storage.dart';

void main() {
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
}
