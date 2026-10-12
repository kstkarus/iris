# iris

An anime client for Android, Windows and iOS. It browses the [Shikimori](https://shikimori.io) catalog, plays episodes from online sources and torrents in its own player, downloads them for offline viewing and syncs watch progress with a Shikimori list.

iris does not host video. It plays streams and torrents published by third-party sources.

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
  <img src="docs/screenshots/title_desktop.png" alt="A title page on a desktop window" width="64%">
  <img src="docs/screenshots/character_phone.png" alt="A character's page" width="24%">
</p>

## Features

- **Catalog.** Popular titles, search, and filters by type, status, genre, season, rating and episode length. When signed in, covers show the title's status in the user's list.
- **Title pages.** Details, description, dubs, related titles, characters with their own pages, and the Shikimori friends who have the title in their lists.
- **Sources.** Online releases in many dubs and subtitles (AniLibria; yummy_anime through Kodik and Aksor), matched by Shikimori id, and torrents from Nyaa. User-added magnet links are kept in the Torrents tab.
- **Player.** mpv through `media_kit`, with the same full-screen controls on every platform:
  - audio and subtitle tracks, subtitle styling, playback speed and decoder choice;
  - a timeline divided by the file's chapters or by the opening and ending;
  - opening skip, based on chapters or [AniSkip](https://api.aniskip.com);
  - next-episode prompt and resume from the last position;
  - on phones, swipe seeking, brightness control and a screen lock.

  Torrents stream piece by piece, without downloading the whole file first.
- **Downloads.** Torrent files and online episodes in a chosen quality. The queue resumes after a pause, an error or an app restart.
- **Shikimori account.** Status, score and episode count for any title. An episode watched to its ending is counted in the list, and episodes the list counts show as watched on every device.
- **Updates.** On Android and Windows the app checks this repository's latest release and offers it when it is newer.

Detailed behaviour of each feature, including which services it calls, is described in [docs/behaviour.md](docs/behaviour.md).

## Status

Android and Windows are built and published on every release. iOS builds from source but has no published build and is tested less.

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

## Development

Requirements:

- Flutter stable (the version is `FLUTTER_VERSION` in `.github/workflows/release.yml`);
- Android Studio, for Android;
- Visual Studio 2022 with "Desktop development with C++", for Windows.

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

Without the file the app builds and runs, and the Profile tab reports that sign-in is not configured. The secret is compiled into the app and can be extracted from a build.

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

The code is organised by feature (`lib/features/<feature>/{presentation,domain,data}`), with shared code in `lib/shared` and `lib/entities`. Conventions, the stack and the player's rules are in [AGENTS.md](AGENTS.md).

## Releases

Pushing a tag `vX.Y.Z` runs `.github/workflows/release.yml`:

```bash
git tag v1.2.0
git push origin v1.2.0
```

The workflow builds the APKs and the Windows archive and publishes them as a GitHub release. The tag becomes the version name and the run number the build number.

It needs two repository secrets (Settings → Secrets and variables → Actions):

- **`ANDROID_DEBUG_KEYSTORE`.** Base64 of the keystore that signs release APKs. Releases are currently signed with the Android debug key, see `android/app/build.gradle.kts`.
  - Android installs an update only over the same signature. The workflow fails without this secret, and also before publishing if the APK's certificate does not match `ANDROID_CERT_SHA256` in the workflow.
  - To encode it on Windows: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore"))`.
- **`SHIKIMORI_CONFIG`.** The contents of `config/shikimori.json`.
