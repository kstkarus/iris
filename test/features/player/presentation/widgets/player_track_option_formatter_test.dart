import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/widgets/player_track_option_formatter.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ru = lookupAppLocalizations(const Locale('ru'));

  test('formats audio track labels from title and language', () {
    expect(_audio(en, const AudioTrack('1', 'Japanese', 'ja')), 'Japanese');
    expect(_audio(en, const AudioTrack('2', null, 'en')), 'English');
    expect(_audio(en, const AudioTrack('3', null, null, codec: 'aac')), 'AAC');
    expect(_audio(en, AudioTrack.auto()), 'Auto');
  });

  test('formats subtitle track labels with off option', () {
    expect(
      _subtitle(en, const SubtitleTrack('10', 'English Signs', 'en')),
      'English Signs',
    );
    expect(_subtitle(en, const SubtitleTrack('11', null, 'ru')), 'Russian');
    expect(_subtitle(en, SubtitleTrack.no()), 'Off');
  });

  test('names languages and unnamed tracks in the app language', () {
    expect(_audio(ru, const AudioTrack('1', null, 'ja')), 'Японский');
    expect(_audio(ru, const AudioTrack('2', null, 'en')), 'Английский');
    expect(_subtitle(ru, const SubtitleTrack('3', null, 'ru')), 'Русский');
    expect(_audio(ru, const AudioTrack('4', null, null)), 'Дорожка');
    expect(_audio(en, const AudioTrack('4', null, null)), 'Track');
    // A title the release gave is its own name.
    expect(_audio(ru, const AudioTrack('5', 'Japanese', 'ja')), 'Japanese');
  });
}

String _audio(AppLocalizations l10n, AudioTrack track) =>
    formatAudioTrackLabel(l10n, track);

String _subtitle(AppLocalizations l10n, SubtitleTrack track) =>
    formatSubtitleTrackLabel(l10n, track);
