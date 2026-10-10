import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/storage/shikimori_session_store.dart';

import '../../helpers/fake_secure_storage.dart';

void main() {
  final tokens = ShikimoriTokens(
    accessToken: 'access',
    refreshToken: 'refresh',
    expiresAt: DateTime.utc(2026, 10, 11, 12),
  );

  test('keeps the session across instances', () async {
    final storage = FakeSecureStorage();
    await ShikimoriSessionStore(storage).write(tokens);

    final restored = await ShikimoriSessionStore(storage).read();

    expect(restored?.accessToken, 'access');
    expect(restored?.refreshToken, 'refresh');
    expect(restored?.expiresAt, tokens.expiresAt);
  });

  test('a sign-out clears the session without reporting it expired', () async {
    final storage = FakeSecureStorage();
    final store = ShikimoriSessionStore(storage);
    final expired = <void>[];
    store.expired.listen(expired.add);
    await store.write(tokens);

    await store.clear();
    await Future<void>.delayed(Duration.zero);

    expect(await store.read(), isNull);
    expect(storage.values, isEmpty);
    expect(expired, isEmpty);
  });

  test('an expired session is cleared and reported', () async {
    final store = ShikimoriSessionStore(FakeSecureStorage());
    final expired = <void>[];
    store.expired.listen(expired.add);
    await store.write(tokens);

    await store.expire();
    await Future<void>.delayed(Duration.zero);

    expect(await store.read(), isNull);
    expect(expired, hasLength(1));
  });

  test('unreadable or broken storage reads as signed out', () async {
    final failing = FakeSecureStorage()..failReads = true;
    expect(await ShikimoriSessionStore(failing).read(), isNull);

    final broken = FakeSecureStorage({'shikimori.session': '{not json'});
    expect(await ShikimoriSessionStore(broken).read(), isNull);
  });
}
