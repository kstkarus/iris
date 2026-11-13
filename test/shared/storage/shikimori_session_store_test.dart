import 'dart:async';
import 'dart:convert';

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

  test('a late read cannot restore a cleared session', () async {
    final storage = _DelayedReads();
    final store = ShikimoriSessionStore(storage);
    final first = store.read();
    final second = store.read();
    final oldValue = jsonEncode(tokens.toJson());

    storage.reads.first.complete(oldValue);
    expect(await first, isNotNull);
    await store.clear();
    storage.reads.last.complete(oldValue);

    expect(await second, isNull);
    expect(await store.read(), isNull);
    expect(storage.values, isEmpty);
  });

  for (final renew in [false, true]) {
    test(
      'a late read cannot replace ${renew ? 'renewed' : 'new'} tokens',
      () async {
        final storage = _DelayedReads();
        final store = ShikimoriSessionStore(storage);
        final initial = store.read();
        final newTokens = ShikimoriTokens(
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          expiresAt: DateTime.utc(2027),
        );

        if (renew) {
          await store.renew(newTokens);
        } else {
          await store.write(newTokens);
        }
        storage.reads.single.complete(jsonEncode(tokens.toJson()));

        expect((await initial)?.accessToken, 'new-access');
        expect((await store.read())?.accessToken, 'new-access');
      },
    );
  }

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

  test('renewing keeps the session generation', () async {
    final store = ShikimoriSessionStore(FakeSecureStorage());
    await store.write(tokens);
    final generation = store.generation;

    await store.renew(
      ShikimoriTokens(
        accessToken: 'renewed-access',
        refreshToken: 'renewed-refresh',
        expiresAt: DateTime.utc(2026, 10, 12, 12),
      ),
    );

    expect(store.generation, generation);
    await store.clear();
    expect(store.generation, generation + 1);
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

class _DelayedReads extends FakeSecureStorage {
  final reads = <Completer<String?>>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      final result = Completer<String?>();
      reads.add(result);
      return result.future;
    }
    return super.noSuchMethod(invocation);
  }
}
