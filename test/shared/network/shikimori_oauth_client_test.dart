import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/dio_factory.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/network/shikimori_oauth_config.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  const config = ShikimoriOAuthConfig(clientId: 'id', clientSecret: 'secret');
  final now = DateTime.utc(2026, 10, 10, 12);

  ShikimoriOAuthClient client(FakeHttpAdapter adapter) => ShikimoriOAuthClient(
    dio: createShikimoriOAuthDio()..httpClientAdapter = adapter,
    config: config,
    now: () => now,
  );

  const tokenReply = FakeReply(200, {
    'access_token': 'access',
    'token_type': 'Bearer',
    'expires_in': 86400,
    'refresh_token': 'refresh',
    'scope': 'user_rates',
    'created_at': 1791633600,
  });

  test('asks for the app, the redirect, the list scope and the state', () {
    final url = client(
      FakeHttpAdapter((_) => tokenReply),
    ).authorizeUrl(state: 'xyz');

    expect(url.origin, 'https://shikimori.io');
    expect(url.path, '/oauth/authorize');
    expect(url.queryParameters, {
      'client_id': 'id',
      'redirect_uri': 'iris://oauth/callback',
      'response_type': 'code',
      'scope': 'user_rates',
      'state': 'xyz',
    });
  });

  test('exchanges a code for tokens that last as long as told', () async {
    final adapter = FakeHttpAdapter((_) => tokenReply);

    final tokens = await client(adapter).exchangeCode('code');

    final request = adapter.requests.single;
    expect(request.path, '/oauth/token');
    expect(request.headers['User-Agent'], 'iris');
    expect(request.contentType, Headers.formUrlEncodedContentType);
    expect(request.data, {
      'grant_type': 'authorization_code',
      'code': 'code',
      'redirect_uri': 'iris://oauth/callback',
      'client_id': 'id',
      'client_secret': 'secret',
    });
    expect(tokens.accessToken, 'access');
    expect(tokens.refreshToken, 'refresh');
    expect(tokens.expiresAt, now.add(const Duration(days: 1)));
  });

  test('renews with the refresh token', () async {
    final adapter = FakeHttpAdapter((_) => tokenReply);

    await client(adapter).refresh('old');

    expect(adapter.requests.single.data, {
      'grant_type': 'refresh_token',
      'refresh_token': 'old',
      'client_id': 'id',
      'client_secret': 'secret',
    });
  });

  test('a refused grant is told apart from other failures', () async {
    final refused = FakeHttpAdapter(
      (_) => const FakeReply(400, {'error': 'invalid_grant'}),
    );
    await expectLater(
      client(refused).refresh('old'),
      throwsA(isA<InvalidGrantException>()),
    );

    final down = FakeHttpAdapter((_) => const FakeReply(503));
    await expectLater(
      client(down).refresh('old'),
      throwsA(
        isA<RemoteResponseException>().having(
          (error) => error,
          'kind',
          isNot(isA<InvalidGrantException>()),
        ),
      ),
    );
  });

  test('a reply without tokens is a response error', () async {
    final adapter = FakeHttpAdapter((_) => const FakeReply(200, {'ok': 1}));

    await expectLater(
      client(adapter).exchangeCode('code'),
      throwsA(isA<RemoteResponseException>()),
    );
  });
}
