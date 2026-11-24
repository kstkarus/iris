import 'package:iris/shared/utils/json_read.dart';

class TenraiEpisodeDto {
  const TenraiEpisodeDto({
    required this.number,
    required this.title,
    required this.filler,
    required this.recap,
  });

  final int? number;
  final String title;
  final bool filler;
  final bool recap;

  factory TenraiEpisodeDto.fromJson(Map<String, dynamic> json) {
    return TenraiEpisodeDto(
      number: jsonIntOrNull(json['mal_id']),
      title: jsonString(json['title']).trim(),
      filler: json['filler'] == true,
      recap: json['recap'] == true,
    );
  }
}
