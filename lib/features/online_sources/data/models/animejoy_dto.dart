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
    this.bestQuality,
  });

  final num number;
  final String title;
  final List<String> playerUrls;
  final int? bestQuality;
}
