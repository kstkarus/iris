import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/domain/online_episode_files.dart';

void main() {
  test('stored online names retain supplied numbers and complete titles', () {
    for (final (number, title) in [
      (2, '«Дело-то вовсе не в магии!»'),
      (720, 'Title'),
      (1000, ''),
      (12.5, 'Dr.Stone'),
    ]) {
      expect(parseOnlineEpisodeFileName(onlineEpisodeFileName(number, title)), (
        number: number,
        title: title,
      ));
    }
    expect(parseOnlineEpisodeFileName('Unnumbered title'), isNull);
  });
}
