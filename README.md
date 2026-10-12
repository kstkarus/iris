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

## Status

Android and Windows builds are published with every release. iOS builds from source; it has no published build and is tested less.

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
- **iOS.** Build from source.

## Disclaimer

iris is not affiliated with Shikimori, AniLibria, yummy_anime, Kodik, Aksor, Nyaa or AniSkip. It does not host or distribute video: it plays streams and torrents published by third parties. You are responsible for complying with the laws of your country. Torrent playback and downloads share data with other peers, who can see your IP address.

## Development

Requirements:

- Flutter 3.47.4, stable channel (the version CI uses, `FLUTTER_VERSION` in `.github/workflows/release.yml`);
- JDK 17 and Android Studio, for Android;
- Visual Studio 2022 with "Desktop development with C++", for Windows;
- Xcode on macOS, for iOS.

```bash
flutter pub get
flutter run --dart-define-from-file=config/shikimori.json
flutter run -d windows --dart-define-from-file=config/shikimori.json
```

### Shikimori sign-in

Sign-in needs a Shikimori OAuth application:

1. Copy `config/shikimori.example.json` to `config/shikimori.json`. That file is ignored by git.
2. Fill in the application's id and secret from https://shikimori.io/oauth/applications.

The application must allow the `user_rates` scope and list these redirect URIs:

- `iris://oauth/callback` (phones);
- `iris-dev://oauth/callback` (Android debug builds);
- `http://127.0.0.1:43821/oauth/callback` (desktop).

Without the file the app builds and runs, and the Profile tab reports that sign-in is not configured.

A Shikimori client secret cannot be kept out of a public client: it is compiled into the app and can be extracted from a build. Forks should register their own application.

### Android debug builds

`flutter run` on Android installs a separate app, "iris dev" (`com.kstkarus.iris.iris.dev`), with its own data. A local build therefore never replaces an installed release or its watch progress and session.

### Checks

```bash
dart format .
flutter analyze
flutter test
```

After editing `lib/l10n/*.arb`, run `flutter gen-l10n`.

### Code structure

The code is organised by feature (`lib/features/<feature>/{presentation,domain,data}`), with shared code in `lib/shared` and `lib/entities`.

## Contributing

Issues and pull requests are welcome. Run the checks above before opening a pull request. The project's conventions, stack and architecture rules are in [AGENTS.md](AGENTS.md), written mainly for coding agents but valid for everyone.

## Versioning

Versions follow [Semantic Versioning](https://semver.org), read from the user's side:

- **Patch** (1.2.**1**): fixes only.
- **Minor** (1.**3**.0): new features or noticeable changes; everything that worked keeps working.
- **Major** (**2**.0.0): changes that break something for existing users, such as a reset or migration of stored data, a raised minimum OS version or a dropped platform.

The version is raised per release, not per commit. Since commits follow [Conventional Commits](https://www.conventionalcommits.org), the weightiest commit since the last release decides: a `feat` makes a minor release, only `fix` commits a patch, and a breaking change a major one. Notable changes are recorded in [CHANGELOG.md](CHANGELOG.md).

## Releases

1. In `CHANGELOG.md`, move the entries under "Unreleased" into a new section `## [X.Y.Z] - YYYY-MM-DD` and update the links at the bottom.
2. Set `version: X.Y.Z+1` in `pubspec.yaml`. CI replaces the build number.
3. Commit, then tag and push:

   ```bash
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

The tag runs `.github/workflows/release.yml`:

- It first checks that the tag matches `pubspec.yaml` and that `CHANGELOG.md` has the version's section, and stops otherwise.
- It builds the APKs and the Windows archive. The tag becomes the version name and the run number the build number.
- It publishes them as a GitHub release, with the changelog section as the release text.

Repository secrets (Settings → Secrets and variables → Actions):

- **`ANDROID_DEBUG_KEYSTORE`** (required). Base64 of the keystore that signs release APKs. Releases are signed with a debug keystore generated on the maintainer's machine, not the publicly known Android test key; see `android/app/build.gradle.kts`.
  - Android installs an update only over the same signature. The workflow fails without this secret, and before publishing if the APK's certificate does not match `ANDROID_CERT_SHA256` in the workflow. A fork must set `ANDROID_CERT_SHA256` to its own key's SHA-256.
  - To encode it on Windows: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore"))`.
- **`SHIKIMORI_CONFIG`** (optional). The contents of `config/shikimori.json`. Without it, releases build with sign-in turned off.

## License

iris is released under the [MIT License](LICENSE). The online source extractors are ported from [anicli-api](https://github.com/vypivshiy/anicli-api) (MIT); this and other third-party licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
