import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/shared/torrent/torrent_key.dart';

void main() {
  test('spells and reads back a release link', () {
    const link = OnlineSourceLink(
      provider: 'anilibria',
      releaseId: '9542',
      animeId: '52991',
    );

    expect(link.toString(), 'online:anilibria/9542?anime=52991');
    expect(OnlineSourceLink.tryParse(link.toString()), link);
  });

  test('keeps a release id that holds a dub', () {
    final releaseId = '10661:${Uri.encodeComponent('Озвучка AniDUB / ТВ')}';
    final link = OnlineSourceLink(
      provider: 'yummyAnime',
      releaseId: releaseId,
      animeId: '52991',
    );

    expect(OnlineSourceLink.tryParse(link.toString())?.releaseId, releaseId);
  });

  test('every dub of an anime shares one progress key', () {
    final anilibria = 'online:anilibria/9542?anime=52991';
    final anidub = 'online:yummyAnime/10661:AniDUB?anime=52991';

    expect(sourceProgressKey(anilibria), sourceProgressKey(anidub));
    expect(sourceProgressKey(anilibria), 'online:anime/52991');
    // Without the anime the release is its own.
    expect(sourceProgressKey('online:anilibria/9542'), 'online:anilibria/9542');
  });

  test('a magnet keeps its torrent key', () {
    const magnet =
        'magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567';

    expect(sourceProgressKey(magnet), torrentKeyFromMagnet(magnet));
  });

  test('reads nothing from a magnet or a malformed link', () {
    for (final value in [
      'magnet:?xt=urn:btih:abc',
      'online:anilibria',
      'online:anilibria/',
      'online:/9542',
      'online:anilibria/1/2',
      '',
    ]) {
      expect(OnlineSourceLink.tryParse(value), isNull, reason: value);
    }
  });
}
