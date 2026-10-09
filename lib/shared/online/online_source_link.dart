import 'package:iris/shared/torrent/torrent_key.dart';

/// Where an online release is, as a magnet link says where a torrent is:
/// `online:anilibria/9542?anime=52991`. It travels where a magnet does (the
/// file picker, the player, watch progress), so a release opens, plays and
/// is continued the way a torrent is.
class OnlineSourceLink {
  const OnlineSourceLink({
    required this.provider,
    required this.releaseId,
    this.animeId = '',
  });

  static const _scheme = 'online:';

  /// The site's name, as the online sources feature spells it.
  final String provider;

  /// The site's id of the release; it may hold a dub (`10661:AniDUB`).
  final String releaseId;

  /// The Shikimori id of the anime; empty when it was not known.
  final String animeId;

  /// Every release of one anime shares this key for watch progress, so a
  /// switch of dub or site keeps the place.
  String get progressKey => animeId.isEmpty
      ? '$_scheme$provider/$releaseId'
      : '${_scheme}anime/$animeId';

  /// The link [value] spells, or null for a magnet or anything else.
  static OnlineSourceLink? tryParse(String value) {
    if (!value.startsWith(_scheme)) return null;
    final rest = value.substring(_scheme.length);
    final slash = rest.indexOf('/');
    if (slash <= 0) return null;
    final provider = rest.substring(0, slash);
    final question = rest.indexOf('?', slash);
    final releaseId = rest.substring(slash + 1, question < 0 ? null : question);
    if (releaseId.isEmpty || releaseId.contains('/')) return null;
    final query = question < 0
        ? const <String, String>{}
        : Uri.splitQueryString(rest.substring(question + 1));
    return OnlineSourceLink(
      provider: provider,
      releaseId: releaseId,
      animeId: query['anime'] ?? '',
    );
  }

  @override
  String toString() => [
    '$_scheme$provider/$releaseId',
    if (animeId.isNotEmpty) '?anime=${Uri.encodeQueryComponent(animeId)}',
  ].join();

  @override
  bool operator ==(Object other) =>
      other is OnlineSourceLink &&
      other.provider == provider &&
      other.releaseId == releaseId &&
      other.animeId == animeId;

  @override
  int get hashCode => Object.hash(provider, releaseId, animeId);
}

/// The watch-progress key of a magnet link or an [OnlineSourceLink].
String sourceProgressKey(String link) =>
    OnlineSourceLink.tryParse(link)?.progressKey ?? torrentKeyFromMagnet(link);
