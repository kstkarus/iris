# Changelog

Notable changes to iris, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as described in [docs/releasing.md](docs/releasing.md). Each release's section becomes the text of its GitHub release.

## [Unreleased]

## [1.4.0] - 2026-10-13

### Changed

- The download picker stays open: tap each episode to queue it, and its row shows the download filling up, then a check. It no longer jumps to the Downloads tab after the first one, so a season for the road is a tap per episode.
- A file whose chapters are only numbered ("Chapter 01", "Chapter 02"…, as disc rips usually come) shows the opening and ending from AniSkip on the timeline when AniSkip knows them, instead of the numbered chapters.

### Fixed

- A downloads list that cannot be saved (a full disk) no longer stalls the queue with a torrent fetching every file instead of the chosen one. The list is saved again later.
- Android: the app no longer crashes when a download's progress updates after the system stopped the download service, and queued downloads keep the service from one to the next while the app is in the background.
- When undoing an episode mark fails, the player says so and its Retry tries the undo again. It said the mark had failed, and Retry marked the episode once more.
- An online release that fails to load no longer hides the other releases of the same anime from that site.
- Leaving a torrent within a moment of opening it no longer leaves it downloading in the background until the next launch.
- A torrent removed from a title's Mine tab while out of sight no longer comes back as a row that still opens it.
- Ctrl+4 on a desktop no longer raises an error: there are three sections, on Ctrl+1 to Ctrl+3.
- The app opens even when the torrent engine fails to start or the downloads list cannot be read. It stayed on a blank screen; now only torrents and downloads report the problem.
- An episode downloaded as one mp4 file carries on after a dropped connection, as segmented episodes do. It failed at once and had to be retried by hand.
- Signing out while the Shikimori session was being renewed could sign you back in once the renewal came back, then on the next launch too.
- A title's page and its sources page show the episodes the player just marked in your Shikimori list. They kept the count from when they opened, so the next "+" on the page could lower it.
- From the second episode on, and after a quality change, the player waits for the new file's first frame again. It counted the first file's frame, so "Start over" was ignored, the 45-second startup timeout never fired and the loading label went early.
- Closing a paused torrent video on Windows no longer hangs for five seconds before the stream is let go.

## [1.3.0] - 2026-10-12

### Added

- Your own torrents are added to an anime from its sources page, as a magnet link or a `.torrent` file, and show on its Mine tab. What plays from them is known to be that anime: Shikimori marks, AniSkip and Continue watching work as for found torrents.

### Removed

- The Torrents tab. Torrents saved there without an anime are not kept.

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

[Unreleased]: https://github.com/kstkarus/iris/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/kstkarus/iris/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/kstkarus/iris/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/kstkarus/iris/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/kstkarus/iris/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/kstkarus/iris/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/kstkarus/iris/releases/tag/v1.1.0
