import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';

class AnimeListItem {
  const AnimeListItem({required this.anime, this.userRate});

  final AnimeSummary anime;

  /// The signed-in user's entry when the page was loaded.
  final UserRate? userRate;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AnimeListItem &&
        other.anime == anime &&
        other.userRate == userRate;
  }

  @override
  int get hashCode => Object.hash(anime, userRate);
}
