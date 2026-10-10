import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_auth_interceptor.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_secure_storage.dart';

void main() {
  final now = DateTime.utc(2026, 10, 10, 12);
  late ShikimoriSessionStore store;
  late _FakeOAuth oauth;
  late FakeHttpAdapter adapter;

  /// The Authorization header of each request as it went out (a repeated
  /// request reuses, and changes, its options).
  late List<Object?> sent;
  late Dio dio;

  /// The server takes only [valid] as a token.
  var valid = 'fresh';

  ShikimoriTokens tokens(
    String access, {
    Duration left = const Duration(hours: 12),
  }) => ShikimoriTokens(
    accessToken: access,
    refreshToken: 'refresh-$access',
    expiresAt: now.add(left),
  );

  setUp(() {
    valid = 'fresh';
    sent = [];
    store = ShikimoriSessionStore(FakeSecureStorage());
    oauth = _FakeOAuth(() => tokens('fresh'));
    adapter = FakeHttpAdapter((options) {
      final auth = options.headers['Authorization'];
      sent.add(auth);
      if (auth == null || auth == 'Bearer $valid') return const FakeReply(200);
      return const FakeReply(401, {'error': 'invalid_token'});
    });
    dio = Dio(BaseOptions(baseUrl: 'https://shikimori.io'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      ShikimoriAuthInterceptor(
        dio: dio,
        store: store,
        oauth: oauth,
        now: () => now,
      ),
    );
  });

  List<Object?> sentTokens() => sent;

  test('without a session requests go anonymous', () async {
    await dio.get<dynamic>('/api/animes');

    expect(sentTokens(), [null]);
    expect(oauth.refreshes, 0);
  });

  test('sends the session token', () async {
    await store.write(tokens('fresh'));

    await dio.get<dynamic>('/api/users/whoami');

    expect(sentTokens(), ['Bearer fresh']);
  });

  test('renews a token about to run out before sending it', () async {
    await store.write(tokens('old', left: const Duration(seconds: 30)));

    await dio.get<dynamic>('/api/users/whoami');

    expect(oauth.refreshes, 1);
    expect(oauth.lastRefreshToken, 'refresh-old');
    expect(sentTokens(), ['Bearer fresh']);
    expect((await store.read())?.accessToken, 'fresh');
  });

  test('a refused token is renewed once and the request repeated', () async {
    await store.write(tokens('revoked'));

    final response = await dio.get<dynamic>('/api/users/whoami');

    expect(response.statusCode, 200);
    expect(sentTokens(), ['Bearer revoked', 'Bearer fresh']);
    expect(oauth.refreshes, 1);
  });

  test('requests refused together renew the token once', () async {
    await store.write(tokens('revoked'));

    await Future.wait([
      dio.get<dynamic>('/api/a'),
      dio.get<dynamic>('/api/b'),
      dio.get<dynamic>('/api/c'),
    ]);

    expect(oauth.refreshes, 1);
  });

  test('a refused renewal ends the session', () async {
    await store.write(tokens('revoked'));
    oauth.failure = const InvalidGrantException('revoked');
    final expired = <void>[];
    store.expired.listen(expired.add);

    await expectLater(
      dio.get<dynamic>('/api/users/whoami'),
      throwsA(
        isA<DioException>().having(
          (error) => error.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(await store.read(), isNull);
    expect(expired, hasLength(1));
  });

  test('a renewal that fails for the network keeps the session', () async {
    await store.write(tokens('revoked'));
    oauth.failure = const NetworkRequestException('offline');

    await expectLater(
      dio.get<dynamic>('/api/users/whoami'),
      throwsA(isA<DioException>()),
    );

    expect((await store.read())?.accessToken, 'revoked');
  });

  test('a repeated request refused again is not renewed again', () async {
    await store.write(tokens('revoked'));
    valid = 'nothing';

    await expectLater(
      dio.get<dynamic>('/api/users/whoami'),
      throwsA(isA<DioException>()),
    );

    expect(oauth.refreshes, 1);
    expect(adapter.requests, hasLength(2));
  });
}

class _FakeOAuth implements ShikimoriOAuthClient {
  _FakeOAuth(this.issue);

  final ShikimoriTokens Function() issue;
  Exception? failure;
  int refreshes = 0;
  String? lastRefreshToken;

  @override
  Future<ShikimoriTokens> refresh(String refreshToken) async {
    refreshes++;
    lastRefreshToken = refreshToken;
    // Lets requests issued together pile up behind the renewal.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final error = failure;
    if (error != null) throw error;
    return issue();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
