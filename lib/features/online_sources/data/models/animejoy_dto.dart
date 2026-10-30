class AnimejoyArticleDto {
  const AnimejoyArticleDto({required this.id, this.shikimoriId});

  final int id;
  final int? shikimoriId;
}

class AnimejoyEpisodeDto {
  const AnimejoyEpisodeDto({
    required this.number,
    required this.title,
    required this.playerUrls,
    this.translation = '',
    this.translationKey,
    this.bestQuality,
    this.kodik,
    this.alloha,
  });

  final num number;
  final String title;
  final List<String> playerUrls;
  final String translation;
  final String? translationKey;
  final int? bestQuality;
  final ({String url, String videoId})? kodik;
  final ({String url, int videoId})? alloha;
}
