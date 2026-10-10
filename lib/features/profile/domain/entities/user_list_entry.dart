import 'package:iris/entities/user_rate/domain/user_rate.dart';

/// What a list row knows of the anime, and what its title page can show
/// before the details load.
class ListedAnime {
  const ListedAnime({
    required this.id,
    required this.name,
    required this.russian,
    required this.kind,
    required this.score,
    required this.status,
    required this.episodes,
    required this.episodesAired,
    required this.airedOn,
    required this.posterUrl,
    this.nextEpisodeAt,
  });

  final String id;
  final String name;
  final String russian;
  final String kind;
  final double score;
  final String status;
  final int episodes;
  final int episodesAired;

  /// As much of the date as is known: `2028`, `2028-03` or `2028-03-15`.
  final String airedOn;
  final String posterUrl;

  /// When the next episode airs, while the anime is airing.
  final DateTime? nextEpisodeAt;
}

/// One anime in a user's Shikimori list.
class UserListEntry {
  const UserListEntry({required this.rate, required this.anime});

  final UserRate rate;
  final ListedAnime anime;
}

/// A page of one status of the list, the most recently changed first.
class UserListPage {
  const UserListPage({required this.entries, required this.hasMore});

  final List<UserListEntry> entries;
  final bool hasMore;
}
