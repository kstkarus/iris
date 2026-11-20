import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/data/datasources/animejoy_data_source.dart';
import 'package:iris/features/online_sources/data/datasources/animejoy_session.dart';
import 'package:iris/features/online_sources/data/repositories/animejoy_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/repositories/animejoy_account_repository.dart';
import 'package:iris/features/player/data/repositories/online_player_repository.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/online/online_source_link.dart';

import '../../../../helpers/fake_http_adapter.dart';
import '../../../../helpers/fake_secure_storage.dart';

const _login = 'iris-test';
const _password = 'test & + password';
const _guest = '''
<form method="post" class="login_form">
  <input name="login_name">
  <input name="login_password" type="password">
  <input name="login" value="submit" type="hidden">
</form>
<script>var dle_group = 5;</script>
''';
const _member = '<script>var dle_group = 4;</script>';
const _guestReply = FakeReply.text(
  200,
  _guest,
  headers: {
    'set-cookie': ['PHPSESSID=guest; Path=/; HttpOnly'],
  },
);
final _home = Uri.parse(animejoyBaseUrl);

String _cookieHeader(RequestOptions request) =>
    request.headers['cookie'] as String? ?? '';

bool _signedIn(RequestOptions request) =>
    _cookieHeader(request).contains('member=valid');

FakeReply _account(RequestOptions request) {
  if (request.method == 'POST') {
    expect(request.uri, _home);
    expect(request.contentType, Headers.formUrlEncodedContentType);
    expect(_cookieHeader(request), 'PHPSESSID=guest');
    final data = request.data as Map<String, String>;
    expect(data['login'], 'submit');
    expect(data['login_name'], _login);
    if (data['login_password'] != _password) return _guestReply;
    return const FakeReply.text(
      302,
      '',
      headers: {
        'location': ['/welcome'],
        'set-cookie': [
          'member=valid; Path=/; Max-Age=3600; Secure; HttpOnly',
          'playlist=valid; Path=/engine/ajax; Max-Age=3600',
          'expired=no; Path=/; Max-Age=0',
        ],
      },
    );
  }
  if (request.uri.path == '/welcome') {
    expect(request.method, 'GET');
    expect(_signedIn(request), isTrue);
  }
  return _signedIn(request) ? const FakeReply.text(200, _member) : _guestReply;
}

AnimejoySession _session(Dio dio, FakeSecureStorage storage) {
  final session = AnimejoySession(dio: dio, storage: storage);
  addTearDown(session.dispose);
  return session;
}

Future<void> _signIn(AnimejoySession session) =>
    session.signIn(login: _login, password: _password);

void main() {
  test('stores durable cookies from a redirect and restores access', () async {
    final storage = FakeSecureStorage({'shikimori.session': 'unrelated'});
    final dio = fakeDio(_account);
    final session = _session(dio, storage);
    final requests = (dio.httpClientAdapter as FakeHttpAdapter).requests;
    expect(await session.hasSavedSession(), isFalse);
    expect(requests, isEmpty);

    final signedIn = session.sessionChanges.first;
    await _signIn(session);
    expect(await signedIn, isTrue);
    expect(requests.map((request) => request.method), [
      'GET',
      'POST',
      'GET',
      'GET',
    ]);

    final saved = storage.values.entries
        .singleWhere((entry) => entry.key.startsWith('animejoy.session'))
        .value;
    expect(saved, allOf(contains('member=valid'), contains('playlist=valid')));
    expect(saved, isNot(contains('PHPSESSID')));
    expect(saved, isNot(contains('expired=no')));
    expect(saved, isNot(contains(_password)));

    final restoredDio = fakeDio(_account);
    final restored = _session(restoredDio, storage);
    final restoredRequests =
        (restoredDio.httpClientAdapter as FakeHttpAdapter).requests;
    expect(await restored.hasSavedSession(), isTrue);
    expect(restoredRequests, isEmpty);

    expect(await restored.restore(), isTrue);
    expect(_cookieHeader(restoredRequests.single), 'member=valid');
    await restored.get(_home.resolve('/engine/ajax/playlists.php'));
    expect(
      _cookieHeader(restoredRequests.last),
      'playlist=valid; member=valid',
    );
    await restored.signOut();
    expect(await restored.hasSavedSession(), isFalse);
    expect(storage.values, {'shikimori.session': 'unrelated'});
  });

  test(
    'a guest response rejects login and preserves an existing session',
    () async {
      final storage = FakeSecureStorage();
      final session = _session(fakeDio(_account), storage);
      await _signIn(session);
      final saved = Map<String, String>.of(storage.values);
      await expectLater(
        session.signIn(login: _login, password: 'wrong password'),
        throwsA(isA<AnimejoySignInRejected>()),
      );
      expect(storage.values, saved);
      expect(await session.restore(), isTrue);
    },
  );

  test('keeps credentials inside the AnimeJoy origin on redirect', () async {
    final storage = FakeSecureStorage();
    final dio = fakeDio((request) {
      expect(request.uri.origin, _home.origin);
      if (request.method == 'GET') return _guestReply;
      return const FakeReply.text(
        307,
        '',
        headers: {
          'location': ['https://otakujoy.fun.other.example/'],
        },
      );
    });
    await expectLater(
      _signIn(_session(dio, storage)),
      throwsA(isA<RemoteResponseException>()),
    );
    expect((dio.httpClientAdapter as FakeHttpAdapter).requests, hasLength(2));
    expect(storage.values, isEmpty);
  });

  test(
    'network failures preserve the session, confirmed guest pages clear it',
    () async {
      final storage = FakeSecureStorage();
      var offline = false;
      var expired = false;
      final session = _session(
        fakeDio((request) {
          if (offline) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionTimeout,
            );
          }
          if (expired) return _guestReply;
          if (request.uri.path == '/forbidden') {
            return const FakeReply.text(403, _guest);
          }
          return _account(request);
        }),
        storage,
      );
      await _signIn(session);
      offline = true;
      await expectLater(
        session.restore(),
        throwsA(isA<NetworkRequestException>()),
      );
      expect(storage.values, isNotEmpty);
      offline = false;
      final forbidden = await session.get(_home.resolve('/forbidden'));
      expect(forbidden.statusCode, 403);
      expect(storage.values, isNotEmpty);
      expired = true;
      final signedOut = session.sessionChanges.first;
      await expectLater(
        session.get(_home.resolve('/index.php?do=search')),
        throwsA(isA<AnimejoySessionChanged>()),
      );
      expect(await signedOut, isFalse);
      expect(storage.values, isEmpty);
      expect(await session.restore(), isFalse);
      expect((await session.get(_home)).statusCode, 200);
    },
  );

  test(
    'a late response after sign-out cannot update or forward old cookies',
    () async {
      final entered = Completer<void>();
      final reply = Completer<FakeReply>();
      final storage = FakeSecureStorage();
      final dio = fakeDio((request) {
        if (request.uri.path == '/slow') {
          expect(_signedIn(request), isTrue);
          entered.complete();
          return reply.future;
        }
        if (request.uri.path == '/after-slow') {
          fail('Followed a stale redirect.');
        }
        return _account(request);
      });
      final session = _session(dio, storage);
      await _signIn(session);
      final pending = expectLater(
        session.get(_home.resolve('/slow')),
        throwsA(isA<AnimejoySessionChanged>()),
      );
      await entered.future;
      await session.signOut();
      reply.complete(
        const FakeReply.text(
          302,
          '',
          headers: {
            'location': ['/after-slow'],
            'set-cookie': ['member=rotated; Path=/; Max-Age=3600'],
          },
        ),
      );
      await pending;
      expect(storage.values, isEmpty);
    },
  );

  test(
    'signed-in catalog and playback share a session, and exit drops cached episodes',
    () async {
      final site = fakeDio((request) {
        final uri = request.uri;
        expect(uri.origin, _home.origin);
        if (uri.path == '/' || uri.path == '/welcome') return _account(request);
        if (uri.queryParameters.containsKey('story')) {
          return const FakeReply.text(200, '''
          <div id="dle-content"><article class="shortstory"><h2>
            <a href="/tv-serialy/410-title.html">Death Note</a>
          </h2></article></div>
        ''');
        }
        if (!_signedIn(request)) return const FakeReply.text(403, _guest);
        if (uri.queryParameters['newsid'] == '410') {
          return const FakeReply.text(
            301,
            '',
            headers: {
              'location': ['/tv-serialy/410-title.html'],
            },
          );
        }
        if (uri.path == '/tv-serialy/410-title.html') {
          return const FakeReply.text(200, '''
          <div class="abasel"><a href="https://shikimori.one/animes/1535">Title</a></div>
        ''');
        }
        if (uri.path == '/engine/ajax/playlists.php') {
          expect(_cookieHeader(request), contains('playlist=valid'));
          return const FakeReply(200, {
            'success': true,
            'response': '''
            <div class="playlists-lists"><ul class="playlists-items">
              <li data-id="0">AllVideo</li>
            </ul></div>
            <div class="playlists-videos"><ul class="playlists-items">
              <li data-id="0" data-file="https://fsst.online/embed/test/">1</li>
            </ul></div>
          ''',
          });
        }
        fail('Unexpected request: $uri');
      });
      final video = fakeDio((request) {
        expect(request.uri.host, 'fsst.online');
        expect(_cookieHeader(request), isEmpty);
        return const FakeReply.text(200, '''
        <script>new Playerjs({id:'Video1',file:'[720p]https://cdn.example/01.mp4'});</script>
      ''');
      })..options.responseType = ResponseType.plain;
      final session = _session(site, FakeSecureStorage());
      final repository = AnimejoyOnlineSourcesRepository(
        dataSource: AnimejoyDataSource(dio: video, session: session),
      );
      final player = OnlinePlayerRepository(
        repository: repository,
        animejoyAccount: session,
      );
      Future<void> expectHidden() => expectLater(
        repository.findReleases(shikimoriId: '1535', titles: ['Death Note']),
        throwsA(isA<RemoteResponseException>()),
      );

      await expectHidden();
      await _signIn(session);
      final releases = await repository.findReleases(
        shikimoriId: '1535',
        titles: ['Death Note'],
      );
      final link = OnlineSourceLink(
        provider: 'animejoy',
        releaseId: releases.single.id,
        animeId: '1535',
      ).toString();
      final prepared = await player.prepareSource(magnet: link);
      expect(prepared.files.single.index, 1);
      final updates = await player
          .startPlayback(sessionId: link, fileIndex: 1)
          .toList();
      final launched = updates.single as PlayerLaunchReadyUpdate;
      expect(launched.session.streamUrl, 'https://cdn.example/01.mp4');

      await session.signOut();
      await expectHidden();
      await expectLater(
        player.prepareSource(magnet: link),
        throwsA(isA<RemoteResponseException>()),
      );
    },
  );
}
