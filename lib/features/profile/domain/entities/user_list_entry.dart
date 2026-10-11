import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';

/// One anime in a user's Shikimori list.
class UserListEntry {
  const UserListEntry({required this.rate, required this.anime});

  final UserRate rate;
  final AnimeSummary anime;
}

/// A page of one status of the list, the most recently changed first.
class UserListPage {
  const UserListPage({required this.entries, required this.hasMore});

  final List<UserListEntry> entries;
  final bool hasMore;
}
