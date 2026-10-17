# Changelog

Notable changes to iris, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) as described in [docs/releasing.md](docs/releasing.md). Each release's section becomes the text of its GitHub release.

## [Unreleased]

## [1.4.5] - 2026-10-17

### Added

- Android updates download inside Iris, with release notes, progress, cancellation and retry. Verified APKs open in Android's system installer, including the install-source permission flow, and remain available after restarting the app.
- Releases include an unsigned iOS IPA, built on macOS without Apple signing credentials. Sign the IPA before installing it on an iPhone or iPad.

### Fixed

- The online sources list no longer replays its transition as other providers answer or finish searching.
- AnimeJoy shows the known maximum quality from its playlist links without extra player requests. Unknown qualities remain hidden.
- Downloads keep their files available when an iOS update or restore changes the app's data-container path. Existing records resolve their relative paths against the current app directory, preserving completed files and resumable progress.

## [1.4.4] - 2026-10-16

### Added

- AnimeJoy online sources, matched by Shikimori ID, with its own player and AllVideo in the existing player and offline downloads. The two mirrors share one episode list; embedded ads and other players are ignored.
- Picture in picture on Windows: the player becomes a small, borderless, resizable window above other apps, with play/pause and a way back to the previous window. It stays inside the monitor's work area when moved. Closing picture in picture returns to the previous window and pauses playback.

### Changed

- Empty Downloads shows a centred explanation of offline viewing and an Open catalog button on phones and desktop. The redundant zero-title counter and divider are removed; storage remains available in More.

### Fixed

- Local playback no longer shows a constant zero download speed or torrent peer count. Decoder and memory details remain available in Technical details.

## [1.4.3] - 2026-10-16

### Changed

- A downloaded title keeps its name available while scrolling: phones show a compact cover and title after the full header scrolls away; Windows keeps the selected title above its episodes.
- Episode rows show the saved playback position and total duration. Release headings show the source and known video quality, with differing qualities beside the corresponding episodes.
- The title menu opens the anime page. Download status keeps live transfer details and failure guidance; completed episodes keep their playback and delete actions.

## [1.4.2] - 2026-10-15

### Changed

- Downloads uses a cover gallery on Android and iOS, and a selectable poster rail beside episodes on Windows. In narrow desktop windows, covers move above the episode list.
- Phone gallery cards align their title and episode-count areas, with small status badges and a separate large-text layout. Completed titles omit the badge; failures remain visible alongside active downloads.
- Episode rows keep an even height. Active downloads show a percentage beside Pause when their size is known; Information holds live sizes, speed, time left, selected quality and failure guidance. Watch marks and resume positions stay visible in the list.
- Storage and cache controls move into the library's More menu. Older downloads gain covers in the background without delaying the local list.

### Fixed

- Long resume positions stay within download rows on very narrow screens with large text; their full value remains in Information.

## [1.4.1] - 2026-10-14

### Added

- Downloads is an offline title library: open an anime to see its releases and episodes, watch progress and selected download quality, or delete all its downloads with confirmation. The picker can queue the remaining episodes together and play a completed one.
- Desktop player: hold Space to play at 2× until you let go; a tap still plays or pauses.

### Changed

- Downloads uses the existing row animations: added titles and episodes develop in, removed ones dissolve and close their space. Reading the initial list and updating progress do not replay that animation.
- On a phone, pinching to fill the screen zooms the video smoothly instead of snapping, and subtitles stay whole while it does.

### Fixed

- Simultaneous cancellation of metadata pickers releases their shared torrent instead of leaving it unowned.
- Opening a download carries the already-known Shikimori episode count into the player without a network request.
- The player does not offer a Shikimori mark after the session ends while its account listener is still catching up.
- An account response arriving after session expiration cannot sign the app back in during startup restore.
- An anime moved into the profile's shown status while another page loads appears after a quiet refresh.
- Canceling a torrent picker while another picker awaits the same metadata no longer removes their shared torrent.
- Download quality choices visibly disable while a batch is added instead of appearing to accept ignored taps.
- Tapping another episode while Download remaining is adding files cannot overtake the batch's episode order.
- Local online playback keeps episode numbers and titles, including specials, so episode order and Shikimori watch marks match streaming.
- The delete-all icon in Downloads has a wider lid separated from the bin, so it is easier to recognise at button size.
- Empty Downloads points to an anime's sources instead of the removed Torrents section.
- Continue and Play next use downloaded episodes of the selected release before preparing a network source; an unfinished episode missing locally falls back to that original source.
- A downloaded episode opens with the other completed episodes of the same release, so Next and the episode drawer keep playing local files.
- Bottom navigation labels keep a gap between them on narrow phones with large text.
- Continue watching shows one entry per anime even after changing torrent or dub, keeping the latest useful progress.
- Changing accounts no longer lets a late Shikimori list response replace the current account's status or episode count, including signing back into the same account. The player clears pending mark and undo notices when the session ends.
- Scrolling a profile list no longer skips titles after several entries leave that status, including changes made while another page loads.
- Android: closing the app clears a download notification even after the system has stopped its foreground service.
- AniLibria: an unavailable release no longer hides an error loading another when neither has an episode to play; the source search offers Retry.
- Android: a downloaded episode opened soon after the app starts no longer crashes the app. The player asked mpv for its state before mpv was ready, which first showed with downloads, since a file on disk opens at once.

## [1.4.0] - 2026-10-13

### Changed

- The download picker stays open: tap each episode to queue it, and its row shows the download filling up, then a check. It no longer jumps to the Downloads tab after the first one, so a season for the road is a tap per episode.
- A file whose chapters are only numbered ("Chapter 01", "Chapter 02"…, as disc rips usually come) shows the opening and ending from AniSkip on the timeline when AniSkip knows them, instead of the numbered chapters.

### Fixed

- Skip opening, "+85 s" and Next episode appear once the video has actually started, and their few seconds on screen pass only while it plays: not before the picture moves, not while paused or loading. Resting the pointer on one fills its bar back up smoothly instead of jumping.
- With the system's animations turned off, the player's offers and notices stayed less than half a second, too short to tap "Mark episode on Shikimori?". They last their full time again.
- The Shikimori mark notice shown right after the resume notice no longer stays on screen until tapped.
- A file whose chapters name only the ending (or only the opening) still offers Skip opening from AniSkip, and an ending chapter counts even when the chapters are read before the file's length.
- After Try Again or a change of quality, the offers wait for the picture again instead of counting down behind the loading spinner.
- On a phone, leaving the app without picture in picture (iOS, older Android, or picture in picture turned off) pauses the video instead of playing and streaming on unseen.
- Stepping 10 s while an episode is still starting no longer throws away the resume position.
- On desktop, the arrow keys and other player keys no longer seek or change the volume while the episodes drawer is open.
- Episodes 480, 720, 1080 and so on of long series (One Piece, Detective Conan) are recognised in file names, so watching them marks the Shikimori list.
- Scrolling further down a list in the profile no longer skips an anime after another one left that list on another screen.
- Changing a title's status or score while its removal from the list is still on its way no longer leaves the page and Shikimori disagreeing. A change that seemed to fail but reached Shikimori shows as saved after a moment, and switching accounts while a change is saved no longer leaves the next one stuck.
- A Shikimori session revoked on the site no longer fails the first page of the catalog; it loads as for a guest.
- A Shikimori "try again later" with a long wait fails at once rather than leaving a spinner turning for that long.
- A short network drop no longer fails every queued online episode one after another; the download waits for the network for a couple of minutes.
- If downloads could not start when the app opened, they start again on the next use instead of failing until the app restarts.
- The downloads list is no longer emptied when the file that keeps it cannot be read for a moment; a damaged one is kept aside.
- Online downloads in mp4 no longer flood the Downloads tab with progress updates.
- Android: the download notification no longer stays behind with nothing downloading, nor after the app is closed; closing the app ends the download, which goes on at the next launch.
- Rows added to a list no longer replay their opening animation when another row comes or goes above them.
- The source tabs (Online, Torrents, Mine) wrap onto a second line in very large text instead of running off a narrow screen.
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

[Unreleased]: https://github.com/kstkarus/iris/compare/v1.4.5...HEAD
[1.4.5]: https://github.com/kstkarus/iris/compare/v1.4.4...v1.4.5
[1.4.4]: https://github.com/kstkarus/iris/compare/v1.4.3...v1.4.4
[1.4.3]: https://github.com/kstkarus/iris/compare/v1.4.2...v1.4.3
[1.4.2]: https://github.com/kstkarus/iris/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/kstkarus/iris/compare/v1.4.0...v1.4.1
[1.4.0]: https://github.com/kstkarus/iris/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/kstkarus/iris/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/kstkarus/iris/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/kstkarus/iris/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/kstkarus/iris/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/kstkarus/iris/releases/tag/v1.1.0
