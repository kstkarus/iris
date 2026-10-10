import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/auth/data/datasources/shikimori_account_data_source.dart';
import 'package:iris/features/auth/data/datasources/web_authenticator.dart';
import 'package:iris/features/auth/data/repositories/shikimori_auth_repository.dart';
import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/domain/entities/shikimori_account.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/network/shikimori_oauth_config.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_secure_storage.dart';

void main() {
  const configured = ShikimoriOAuthConfig(clientId: 'id', clientSecret: 's');
  const account = ShikimoriAccount(
    id: '42',
    nickname: 'kstk',
    avatarUrl: 'https://shikimori.io/a.png',
  );
  const currentUser = FakeReply(200, {
    'data': {
      'currentUser': {
        'id': '42',
        'nickname': 'kstk',
        'avatarUrl': 'https://shikimori.io/a.png',
      },
    },
  });
  const anonymous = FakeReply(200, {
    'data': {'currentUser': null},
  });
  const tokens = FakeReply(200, {
    'access_token': 'access',
    'refresh_token': 'refresh',
    'expires_in': 86400,
  });

  late FakeSecureStorage storage;
  late ShikimoriSessionStore session;
  late SharedPreferences preferences;
  late _FakeAuthenticator authenticator;
  late FakeReply Function(RequestOptions) server;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    storage = FakeSecureStorage();
    session = ShikimoriSessionStore(storage);
    authenticator = _FakeAuthenticator();
    server = (options) => switch (options.path) {
      '/oauth/token' => tokens,
      _ => currentUser,
    };
  });

  ShikimoriAuthRepository repository({
    ShikimoriOAuthConfig config = configured,
    bool platformSupported = true,
  }) {
    final adapter = FakeHttpAdapter((options) => server(options));
    Dio dio() =>
        Dio(BaseOptions(baseUrl: 'https://shikimori.io'))
          ..httpClientAdapter = adapter;
    return ShikimoriAuthRepository(
      oauth: ShikimoriOAuthClient(dio: dio(), config: config),
      session: session,
      accounts: ShikimoriAccountDataSource(
        client: ShikimoriGraphQlClient(dio: dio()),
      ),
      authenticator: authenticator,
      preferences: preferences,
      platformSupported: platformSupported,
    );
  }

  group('signIn', () {
    test('trades the code for a session and returns the account', () async {
      final result = await repository().signIn();

      expect(result, account);
      expect((await session.read())?.accessToken, 'access');
      final asked = authenticator.asked!;
      expect(asked.path, '/oauth/authorize');
      expect(asked.queryParameters['state'], hasLength(greaterThan(16)));
    });

    test('a redirect for another sign-in is refused', () async {
      authenticator.reply = (_) =>
          Uri.parse('iris://oauth/callback?code=c&state=forged');

      await expectLater(repository().signIn(), throwsA(isA<AuthRejected>()));
      expect(await session.read(), isNull);
    });

    test('declining on Shikimori is a cancel', () async {
      authenticator.reply = (url) => Uri.parse(
        'iris://oauth/callback?error=access_denied'
        '&state=${url.queryParameters['state']}',
      );

      await expectLater(repository().signIn(), throwsA(isA<AuthCancelled>()));
    });

    test('closing the page is a cancel', () async {
      authenticator.failure = const AuthCancelled();

      await expectLater(repository().signIn(), throwsA(isA<AuthCancelled>()));
    });

    test('a refused code leaves no session behind', () async {
      server = (options) => switch (options.path) {
        '/oauth/token' => const FakeReply(400, {'error': 'invalid_grant'}),
        _ => currentUser,
      };

      await expectLater(repository().signIn(), throwsA(isA<AuthRejected>()));
      expect(await session.read(), isNull);
    });

    test('a session that names no account is dropped', () async {
      server = (options) => switch (options.path) {
        '/oauth/token' => tokens,
        _ => anonymous,
      };

      await expectLater(repository().signIn(), throwsA(isA<AuthRejected>()));
      expect(storage.values, isEmpty);
    });

    test('without credentials or platform support it is unavailable', () async {
      const empty = ShikimoriOAuthConfig(clientId: '', clientSecret: '');
      expect(repository(config: empty).canSignIn, isFalse);
      expect(repository(platformSupported: false).canSignIn, isFalse);

      await expectLater(
        repository(config: empty).signIn(),
        throwsA(isA<AuthUnavailable>()),
      );
      expect(authenticator.asked, isNull);
    });
  });

  group('restore', () {
    test('without a session there is no account', () async {
      expect(await repository().restore(), isNull);
    });

    test('a kept session comes back with its account', () async {
      await repository().signIn();

      expect(await repository().restore(), account);
    });

    test('offline, the account last seen stands in', () async {
      await repository().signIn();
      server = (_) => throw const SocketLikeFailure();

      expect(await repository().restore(), account);
    });

    test('a session Shikimori no longer knows is signed out', () async {
      await repository().signIn();
      server = (_) => anonymous;

      expect(await repository().restore(), isNull);
      expect(await session.read(), isNull);
    });
  });

  test('signOut forgets the session and the account', () async {
    final auth = repository();
    await auth.signIn();

    await auth.signOut();

    expect(await session.read(), isNull);
    expect(preferences.getKeys(), isEmpty);
  });
}

/// Thrown by the fake server like a dropped connection.
class SocketLikeFailure implements Exception {
  const SocketLikeFailure();
}

class _FakeAuthenticator implements WebAuthenticator {
  Uri? asked;
  AuthFailure? failure;

  /// Answers with a code for the state asked.
  Uri Function(Uri url) reply = (url) => Uri.parse(
    'iris://oauth/callback?code=code&state=${url.queryParameters['state']}',
  );

  @override
  Future<Uri> authenticate(Uri url) async {
    asked = url;
    final failure = this.failure;
    if (failure != null) throw failure;
    return reply(url);
  }
}
