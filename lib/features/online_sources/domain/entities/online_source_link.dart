import 'package:iris/features/online_sources/domain/entities/online_provider.dart';

/// Where an online release is, as a magnet link says where a torrent is:
/// `online:anilibria/9542`. It travels where a magnet does (the file
/// picker, the player, watch progress), so a release opens, plays and is
/// continued the way a torrent is.
class OnlineSourceLink {
  const OnlineSourceLink({required this.provider, required this.releaseId});

  static const _scheme = 'online:';

  final OnlineProvider provider;
  final String releaseId;

  /// The link [value] spells, or null for a magnet or anything else.
  static OnlineSourceLink? tryParse(String value) {
    if (!value.startsWith(_scheme)) return null;
    final parts = value.substring(_scheme.length).split('/');
    if (parts.length != 2 || parts[1].isEmpty) return null;
    for (final provider in OnlineProvider.values) {
      if (provider.name == parts[0]) {
        return OnlineSourceLink(provider: provider, releaseId: parts[1]);
      }
    }
    return null;
  }

  @override
  String toString() => '$_scheme${provider.name}/$releaseId';

  @override
  bool operator ==(Object other) =>
      other is OnlineSourceLink &&
      other.provider == provider &&
      other.releaseId == releaseId;

  @override
  int get hashCode => Object.hash(provider, releaseId);
}
