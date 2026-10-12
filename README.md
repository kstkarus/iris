# iris

An ad-free anime client for Android, Windows and iOS. It browses the [Shikimori](https://shikimori.io) catalog, plays episodes from online sources and torrents in its own player, downloads them for offline viewing and syncs watch progress with a Shikimori list.

The interface is in English and Russian. Online sources offer Russian dubs and subtitles only; torrents come in whatever languages their releases have.

## Features

- **Catalog.** Popular titles, search, and filters by type, status, genre, season, rating and episode length. When signed in, covers show the title's status in your list.
- **Title pages.** Details, description, dubs, related titles, characters with their own pages, and the Shikimori friends who have the title in their lists.
- **Sources.** Online releases from AniLibria and yummy_anime, which serve them through several video hosts, and torrents from Nyaa through a public API mirror. Magnet links you add yourself are kept in the Torrents tab.
- **Player.** mpv through `media_kit`, with the same full-screen controls on every platform:
  - audio and subtitle tracks, subtitle styling, playback speed and decoder choice;
  - a timeline divided by the file's chapters or by the opening and ending;
  - opening skip, based on chapters or [AniSkip](https://api.aniskip.com);
  - next-episode prompt and resume from the last position;
  - on phones, swipe seeking, brightness control and a screen lock.

  Torrents stream piece by piece, without downloading the whole file first.
- **Downloads.** Torrent files and online episodes in a chosen quality. The queue resumes after a pause, an error or an app restart.
- **Shikimori account.** Status, score and episode count for any title. Finishing an episode updates the count in your list, and episodes counted there show as watched on every device.
- **Updates.** On Android and Windows the app checks this repository's latest release and offers it when it is newer.

How each feature behaves, and which services it calls, is described in [docs/behaviour.md](docs/behaviour.md).

## Screenshots

<p align="center">
  <img src="docs/screenshots/catalog_desktop.png" alt="The catalog on a desktop window" width="100%">
</p>

<p align="center">
  <img src="docs/screenshots/catalog_phone.png" alt="The catalog on a phone" width="24%">
  <img src="docs/screenshots/title_phone.png" alt="A title page" width="24%">
  <img src="docs/screenshots/characters_phone.png" alt="Related titles and characters on a title page" width="24%">
  <img src="docs/screenshots/sources_phone.png" alt="Online dubs of a title" width="24%">
</p>

<p align="center">
  <img src="docs/screenshots/title_desktop.png" alt="A title page on a desktop window" width="69.2%">
  <img src="docs/screenshots/character_phone.png" alt="A character's page" width="20%">
</p>

## Install

Builds are published on the [Releases](https://github.com/kstkarus/iris/releases) page.

- **Android.** Choose the APK for your device's processor:

  | APK | For |
  |---|---|
  | `iris-X.Y.Z-android-arm64-v8a.apk` | most phones |
  | `iris-X.Y.Z-android-armeabi-v7a.apk` | older 32-bit phones |
  | `iris-X.Y.Z-android-x86_64.apk` | emulators and Chromebooks |
  | `iris-X.Y.Z-android-universal.apk` | any device (about twice the size) |

  Any of these installs over another. The app then offers updates for its own processor.
- **Windows.** `iris-X.Y.Z-windows-x64.zip`. Unpack it and run `iris.exe`. To update, unpack the new archive over the old folder.
- **iOS.** No published build; build it from source (see Development). Tested less than Android and Windows.

## Disclaimer

iris is not affiliated with Shikimori, AniLibria, yummy_anime, Kodik, Aksor, Nyaa or AniSkip. It does not host or distribute video: it plays streams and torrents published by third parties. You are responsible for complying with the laws of your country. Torrent playback and downloads share data with other peers, who can see your IP address.

## Development

Requirements:

- Flutter 3.47.4, stable channel (the version CI uses);
- JDK 17 and Android Studio, for Android;
- Visual Studio 2022 with "Desktop development with C++", for Windows;
- Xcode on macOS, for iOS.

```bash
flutter pub get
flutter run --dart-define-from-file=config/shikimori.json
flutter run -d windows --dart-define-from-file=config/shikimori.json
```

On Android, `flutter run` installs a separate "iris dev" app, so a local build never replaces an installed release or its data.

### Shikimori sign-in (optional)

Copy `config/shikimori.example.json` to `config/shikimori.json` (git-ignored) and fill in the id and secret of a [Shikimori OAuth application](https://shikimori.io/oauth/applications). It needs the `user_rates` scope and these redirect URIs: `iris://oauth/callback`, `iris-dev://oauth/callback` and `http://127.0.0.1:43821/oauth/callback`. Without the file, sign-in is turned off. The secret is compiled into the app and can be extracted from a build, so forks should register their own application.

## Contributing

Issues and pull requests are welcome. Before opening one, run `dart format .`, `flutter analyze` and `flutter test`, and `flutter gen-l10n` after editing `lib/l10n/*.arb`. Conventions and architecture are in [AGENTS.md](AGENTS.md), written mainly for coding agents but valid for everyone. Versioning and releases are in [docs/releasing.md](docs/releasing.md).

## License

iris is released under the [MIT License](LICENSE). The online source extractors are ported from [anicli-api](https://github.com/vypivshiy/anicli-api) (MIT); this and other third-party licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
