# Changelog

Notable changes to iris, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as described in [docs/releasing.md](docs/releasing.md). Each release's section becomes the text of its GitHub release.

## [Unreleased]

## [1.2.1] - 2026-10-12

### Fixed

- The halftone cover on a title's page keeps the same detail at any size. On phones it was much coarser than on a desktop.
- The time above the player's timeline no longer breaks onto a second line on Android, where it was measured in the wrong font.
- Watching the last episode of an anime that was planned, on hold, dropped or not in the Shikimori list marks it completed. It stayed as watching, as with a film watched straight from its page.

## [1.2.0] - 2026-10-12

### Added

- The player's timeline is divided into parts: by the file's chapters, or around the opening, ending and recap from AniSkip. Seeking shows the part's name next to the time.
- Picture in picture on Android: from the player's button, or by itself when leaving the app while a video plays. The small window has a play/pause button; closing it pauses.

### Changed

- The update notice sits at the top of the tab pages. On phones it was above the bottom tabs.
- Android debug builds install as a separate app, "iris dev", so a local build never replaces a release or its data.

### Fixed

- Japanese names on character pages are shown in the bundled Noto Sans CJK font on every platform.

## [1.1.1] - 2026-10-12

### Changed

- Android releases come as one APK per processor type (arm64-v8a, armeabi-v7a, x86_64) plus a universal APK. The arm64 APK is about half the size of the previous single APK. The app offers the update for its own processor.

## [1.1.0] - 2026-10-12

First published release.

### Added

- Catalog: popular titles from Shikimori, search, and filters by type, status, genre, season, rating and episode length.
- Title pages: details, description, dubs, related titles, characters and character pages, and Shikimori friends who have the title.
- Online sources (AniLibria, yummy_anime) and torrents from Nyaa, plus user-added magnet links.
- Player: the app's own full-screen controls, audio and subtitle tracks, subtitle styling, playback speed, decoder choice, opening skip, next-episode prompt and resume. Torrents stream without a full download.
- Downloads of torrent files and online episodes, resumed after a pause, an error or a restart.
- Shikimori sign-in: list status, score and episodes, and episodes marked as watched from the list.
- Update notice on Android and Windows when a newer release is published.
- App icon.

[Unreleased]: https://github.com/kstkarus/iris/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/kstkarus/iris/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/kstkarus/iris/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/kstkarus/iris/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/kstkarus/iris/releases/tag/v1.1.0
