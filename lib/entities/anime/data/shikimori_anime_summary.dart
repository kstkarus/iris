import 'package:iris/entities/anime/domain/anime_summary.dart';
import 'package:iris/shared/utils/incomplete_date.dart';
import 'package:iris/shared/utils/json_read.dart';

/// The GraphQL fields [parseShikimoriAnimeSummary] reads, poster aside: a
/// list asks for `poster { mainUrl }`, the title page for `originalUrl`.
const shikimoriAnimeSummaryFields = '''
id
name
russian
english
kind
score
status
episodes
episodesAired
airedOn {
  year
  month
  day
  date
}
''';

/// An `Anime` of the GraphQL API; null when [json] is not one or has no id.
/// Missing or mistyped fields read as empty or 0. The poster comes from
/// [posterUrlField] of `poster`.
AnimeSummary? parseShikimoriAnimeSummary(
  Object? json, {
  String posterUrlField = 'mainUrl',
}) {
  if (json is! Map) return null;
  final id = json['id'];
  if (id == null) return null;
  return AnimeSummary(
    id: '$id',
    name: jsonString(json['name']),
    russian: jsonString(json['russian']),
    english: jsonString(json['english']),
    kind: jsonString(json['kind']),
    score: jsonNum(json['score']).toDouble(),
    status: jsonString(json['status']),
    episodes: jsonInt(json['episodes']),
    episodesAired: jsonInt(json['episodesAired']),
    airedOn: _airedOn(json['airedOn']),
    posterUrl: jsonString(jsonMap(json['poster'])[posterUrlField]),
    nextEpisodeAt: DateTime.tryParse(jsonString(json['nextEpisodeAt'])),
  );
}

/// An `airedOn` (`IncompleteDate`) as an [incompleteIsoDate].
String _airedOn(Object? json) {
  final date = jsonMap(json);
  return incompleteIsoDate(
    year: jsonInt(date['year']),
    month: jsonInt(date['month']),
    day: jsonInt(date['day']),
    date: jsonString(date['date']),
  );
}
