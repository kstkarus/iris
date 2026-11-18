import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:html/parser.dart' show parse;

import 'package:iris/features/online_sources/data/datasources/animejoy_cookies.dart';
import 'package:iris/features/online_sources/domain/repositories/animejoy_account_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/utils/serial_queue.dart';

const animejoyBaseUrl = 'https://otakujoy.fun/';

/// The login and catalog share cookies. Each login attempt has its own cookies
/// until the site confirms the account.
class AnimejoySession implements AnimejoyAccountRepository {
  AnimejoySession({
    required Dio dio,
    required FlutterSecureStorage storage,
    String baseUrl = animejoyBaseUrl,
  }) : _dio = dio,
       _storage = storage,
       baseUri = Uri.parse(baseUrl);

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final Uri baseUri;
  final _changes = SerialQueue();
  final _sessionChanges = StreamController<bool>.broadcast();

  AnimejoyCookies _cookies = AnimejoyCookies();
  Future<void>? _load;
  String? _saved;
  bool _hasAccount = false;
  int _generation = 0;

  String get _storageKey => 'animejoy.session.${baseUri.host}.${baseUri.port}';

  @override
  int get generation => _generation;

  @override
  Stream<bool> get sessionChanges => _sessionChanges.stream;

  @override
  Future<bool> restore() => _changes.run(() async {
    await _ensureLoaded();
    if (!_hasAccount) return false;
    if (!await _verify(_cookies)) {
      await _forget();
      return false;
    }
    await _persist(_cookies);
    return true;
  });

  @override
  Future<void> signIn({
    required String login,
    required String password,
  }) => _changes.run(() async {
    if (login.trim().isEmpty || password.isEmpty) {
      throw const AnimejoySignInRejected();
    }
    await _ensureLoaded();
    final pending = AnimejoyCookies();
    final home = await _request(pending, baseUri);
    _requireSuccess(home);
    final form = parse(home.data ?? '').querySelector('form.login_form');
    if (form == null || form.attributes['method']?.toLowerCase() != 'post') {
      throw const RemoteResponseException('AnimeJoy login form is missing.');
    }
    final action = Uri.tryParse(form.attributes['action'] ?? '');
    if (action == null) {
      throw const RemoteResponseException('Invalid AnimeJoy login form.');
    }
    final loggedIn = await _request(
      pending,
      home.realUri.resolveUri(action),
      form: {
        'login_name': login,
        'login_password': password,
        'login': 'submit',
      },
    );
    if (loggedIn.statusCode == HttpStatus.unauthorized) {
      throw const AnimejoySignInRejected();
    }
    _requireSuccess(loggedIn);
    if (!await _verify(pending)) throw const AnimejoySignInRejected();
    await _writeSaved(_encode(pending));
    _publish(pending, hasAccount: true);
  });

  @override
  Future<void> signOut() => _changes.run(() async {
    await _ensureLoaded();
    await _forget();
  });

  Future<Response<String>> get(Uri uri) async {
    await _ensureLoaded();
    final cookies = _cookies;
    final response = await _request(cookies, uri);
    _requireCurrent(cookies);
    if (!_hasAccount) return response;

    if (response.data?.contains('login_form') == true &&
        _accountPage(response.data) == _AccountPage.guest) {
      await _changes.run(() async {
        _requireCurrent(cookies);
        if (!await _verify(cookies)) await _forget();
      });
      _requireCurrent(cookies);
    }
    if (_encode(cookies) != _saved) {
      await _changes.run(() async {
        _requireCurrent(cookies);
        await _persist(cookies);
      });
    }
    _requireCurrent(cookies);
    return response;
  }

  Future<void> dispose() async {
    _dio.close(force: true);
    await _changes.idle;
    await _sessionChanges.close();
  }

  Future<bool> _verify(AnimejoyCookies cookies) async {
    final response = await _request(cookies, baseUri);
    _requireSuccess(response);
    return switch (_accountPage(response.data)) {
      _AccountPage.guest => false,
      _AccountPage.signedIn when cookies.headerFor(baseUri) != null => true,
      _ => throw const RemoteResponseException(
        'AnimeJoy account could not be verified.',
      ),
    };
  }

  Future<Response<String>> _request(
    AnimejoyCookies cookies,
    Uri uri, {
    Map<String, String>? form,
  }) async {
    final active = identical(cookies, _cookies);
    var target = uri;
    var body = form;
    for (var redirects = 0; redirects <= 5; redirects++) {
      if (active) _requireCurrent(cookies);
      if (target.scheme != 'https' ||
          target.userInfo.isNotEmpty ||
          target.host != baseUri.host ||
          target.port != baseUri.port) {
        throw const RemoteResponseException('Unexpected AnimeJoy origin.');
      }
      final Response<String> response;
      try {
        response = await _dio.requestUri<String>(
          target,
          data: body,
          options: Options(
            method: body == null ? 'GET' : 'POST',
            responseType: ResponseType.plain,
            followRedirects: false,
            validateStatus: (_) => true,
            contentType: body == null
                ? null
                : Headers.formUrlEncodedContentType,
            headers: {
              'Accept': 'text/html,application/json;q=0.9,*/*;q=0.8',
              'Cache-Control': 'no-cache',
              'Cookie': ?cookies.headerFor(target),
              if (body != null) 'Origin': baseUri.origin,
              if (body != null) 'Referer': baseUri.toString(),
            },
          ),
        );
      } on DioException {
        throw const NetworkRequestException('Unable to reach AnimeJoy.');
      }
      cookies.accept(
        target,
        response.headers[HttpHeaders.setCookieHeader] ?? const [],
      );
      final status = response.statusCode;
      if (!const {301, 302, 303, 307, 308}.contains(status)) return response;
      final location =
          response.headers[HttpHeaders.locationHeader]?.firstOrNull;
      final destination = location == null ? null : Uri.tryParse(location);
      if (destination == null || location!.isEmpty) break;
      target = target.resolveUri(destination);
      if (status == 301 || status == 302 || status == 303) body = null;
    }
    throw const RemoteResponseException('Invalid AnimeJoy redirect.');
  }

  Future<void> _ensureLoaded() => _load ??= _readSaved();

  Future<void> _readSaved() async {
    try {
      _saved = await _storage.read(key: _storageKey);
      final saved = _saved;
      if (saved == null) return;
      final decoded = jsonDecode(saved);
      if (decoded is! List || decoded.any((value) => value is! String)) return;
      final cookies = AnimejoyCookies()
        ..accept(baseUri, decoded.cast<String>());
      if (cookies.persistent().isEmpty) {
        await _writeSaved(null);
        return;
      }
      _cookies = cookies;
      _hasAccount = true;
    } on Exception {
      // Online sources still work as a guest when the keystore is unavailable.
    }
  }

  String? _encode(AnimejoyCookies cookies) {
    final persistent = cookies.persistent();
    return persistent.isEmpty ? null : jsonEncode(persistent);
  }

  Future<void> _persist(AnimejoyCookies cookies) async {
    final value = _encode(cookies);
    if (value != _saved) await _writeSaved(value);
  }

  Future<void> _writeSaved(String? value) async {
    if (value == null) {
      await _storage.delete(key: _storageKey);
    } else {
      await _storage.write(key: _storageKey, value: value);
    }
    _saved = value;
  }

  Future<void> _forget() async {
    await _writeSaved(null);
    _publish(AnimejoyCookies(), hasAccount: false);
  }

  void _publish(AnimejoyCookies cookies, {required bool hasAccount}) {
    _cookies = cookies;
    _hasAccount = hasAccount;
    _generation++;
    _sessionChanges.add(hasAccount);
  }

  void _requireCurrent(AnimejoyCookies cookies) {
    if (!identical(cookies, _cookies)) throw const AnimejoySessionChanged();
  }

  static void _requireSuccess(Response<String> response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw RemoteResponseException(
        'AnimeJoy answered $status.',
        statusCode: status,
      );
    }
  }
}

enum _AccountPage { guest, signedIn, unknown }

// AnimeJoy's DataLife Engine pages identify guests as group 5.
final _accountGroup = RegExp(
  r'^\s*(?:var\s+)?dle_group\s*=\s*(\d+)\s*;',
  multiLine: true,
);

_AccountPage _accountPage(String? html) {
  if (html == null ||
      !(html.contains('dle_group') || html.contains('login_form'))) {
    return _AccountPage.unknown;
  }
  final document = parse(html);
  if (document.querySelector('form.login_form input[name="login_password"]') !=
      null) {
    return _AccountPage.guest;
  }
  for (final script in document.querySelectorAll('script:not([src])')) {
    final group = int.tryParse(_accountGroup.firstMatch(script.text)?[1] ?? '');
    if (group == 5) return _AccountPage.guest;
    if (group != null && group > 0) return _AccountPage.signedIn;
  }
  return _AccountPage.unknown;
}
