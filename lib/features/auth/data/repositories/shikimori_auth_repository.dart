import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/auth/data/datasources/shikimori_account_data_source.dart';
import 'package:iris/features/auth/data/datasources/web_authenticator.dart';
import 'package:iris/features/auth/data/models/shikimori_account_dto.dart';
import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/domain/entities/shikimori_account.dart';
import 'package:iris/features/auth/domain/repositories/auth_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_oauth_client.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';

/// Signs in through Shikimori's OAuth page (authorization code flow).
///
/// The tokens stay in secure storage; the account's public card (id,
/// nickname, avatar) is kept in preferences, so a session restored offline
/// still knows whose it is.
class ShikimoriAuthRepository implements AuthRepository {
  ShikimoriAuthRepository({
    required ShikimoriOAuthClient oauth,
    required ShikimoriSessionStore session,
    required ShikimoriAccountDataSource accounts,
    required WebAuthenticator authenticator,
    required SharedPreferences preferences,
    required bool platformSupported,
    Random? random,
  }) : _oauth = oauth,
       _session = session,
       _accounts = accounts,
       _authenticator = authenticator,
       _preferences = preferences,
       _platformSupported = platformSupported,
       _random = random ?? Random.secure();

  static const _accountKey = 'auth.account';

  final ShikimoriOAuthClient _oauth;
  final ShikimoriSessionStore _session;
  final ShikimoriAccountDataSource _accounts;
  final WebAuthenticator _authenticator;
  final SharedPreferences _preferences;
  final bool _platformSupported;
  final Random _random;

  @override
  bool get canSignIn => _platformSupported && _oauth.isConfigured;

  @override
  Stream<void> get sessionExpired => _session.expired;

  @override
  Future<ShikimoriAccount?> restore() async {
    if (await _session.read() == null) {
      await _forgetAccount();
      return null;
    }
    final ShikimoriAccountDto? fresh;
    try {
      fresh = await _accounts.fetchCurrent();
    } on Exception {
      // Offline, or the session just ended (then the store is empty).
      if (await _session.read() == null) return null;
      return _cachedAccount()?.toEntity();
    }
    if (fresh == null) {
      await signOut();
      return null;
    }
    await _cacheAccount(fresh);
    return fresh.toEntity();
  }

  @override
  Future<ShikimoriAccount> signIn() async {
    if (!canSignIn) throw const AuthUnavailable();
    final state = _newState();
    final callback = await _authenticator.authenticate(
      _oauth.authorizeUrl(state: state),
    );
    final params = callback.queryParameters;
    if (params['state'] != state) throw const AuthRejected();
    if (params['error'] == 'access_denied') throw const AuthCancelled();
    final code = params['code'];
    if (code == null || code.isEmpty) throw const AuthRejected();

    try {
      await _session.write(await _oauth.exchangeCode(code));
      final account = await _accounts.fetchCurrent();
      if (account == null) throw const AuthRejected();
      await _cacheAccount(account);
      return account.toEntity();
    } on Exception catch (error) {
      await _session.clear();
      throw switch (error) {
        AuthFailure() => error,
        NetworkRequestException() => const AuthNetworkFailure(),
        _ => const AuthRejected(),
      };
    }
  }

  @override
  Future<void> signOut() async {
    await _session.clear();
    await _forgetAccount();
  }

  /// Ties the redirect to this sign-in, so a link from elsewhere cannot
  /// slip in another code.
  String _newState() => base64Url
      .encode(List<int>.generate(16, (_) => _random.nextInt(256)))
      .replaceAll('=', '');

  ShikimoriAccountDto? _cachedAccount() {
    final value = _preferences.getString(_accountKey);
    if (value == null) return null;
    try {
      return ShikimoriAccountDto.tryParse(jsonDecode(value));
    } on FormatException {
      return null;
    }
  }

  Future<void> _cacheAccount(ShikimoriAccountDto account) =>
      _preferences.setString(_accountKey, jsonEncode(account.toJson()));

  Future<void> _forgetAccount() => _preferences.remove(_accountKey);
}
