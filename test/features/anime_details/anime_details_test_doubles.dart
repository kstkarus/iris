import 'dart:async';

import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/features/anime_details/domain/entities/anime_details.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';

const fmaDetails = AnimeDetails(
  anime: AnimeSummary(
    id: '5114',
    name: 'Fullmetal Alchemist: Brotherhood',
    russian: 'Fullmetal Alchemist: Brotherhood RU',
    kind: 'tv',
    score: 9.12,
    status: 'released',
    episodes: 64,
    episodesAired: 64,
    airedOn: '2009-04-05',
    posterUrl: 'https://shikimori.one/posters/5114/original.jpg',
  ),
  description:
      'Two brothers search for a Philosopher\'s Stone after a failed ritual.',
);

/// Answers every request with [details].
class FixedAnimeDetailsRepository implements AnimeDetailsRepository {
  const FixedAnimeDetailsRepository([this.details = fmaDetails]);

  final AnimeDetails details;

  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) async => details;
}

/// Answers every request with [answer], which by default never completes.
class PendingAnimeDetailsRepository implements AnimeDetailsRepository {
  PendingAnimeDetailsRepository([Future<AnimeDetails>? answer])
    : answer = answer ?? Completer<AnimeDetails>().future;

  final Future<AnimeDetails> answer;

  @override
  Future<AnimeDetails> fetchAnimeDetails(String id) => answer;
}
