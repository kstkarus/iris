# iris

`iris` is a Flutter app (Android, iOS, Windows) for browsing anime and streaming episodes from torrents in the in-app player. Downloading episodes for offline viewing is a secondary feature.

The project follows a feature-first structure with `FSD light` at the repository level and `clean arch` inside each feature.

## Current Product Scope

- browse anime titles
- open anime details
- search and filter the catalog
- find torrent-based watch sources
- save your own magnet links in the Torrents tab and stream or download them later
- choose a video file when a torrent contains multiple episodes
- stream the selected file in the in-app player
- optionally download a file for offline viewing and manage queued, active, paused, completed, and failed downloads
- continue an active download while the Android app is minimized
- view app, cache, and offline-content storage usage
- customize subtitle appearance and decoding mode in the player

## Data Sources

### Anime Catalog

The app currently reads public anime data from the Shikimori GraphQL API:

- endpoint: `https://shikimori.one/api/graphql`
- read-only integration
- user authorization is not connected yet

### Watch Sources

The watch sources screen currently uses the public `nyaaapi` service:

- endpoint: `https://nyaaapi.onrender.com/nyaa`
- read-only lookup by anime English title
- only Nyaa's anime section is requested (`category=anime`), and anime music videos are dropped, so soundtracks, manga and AMVs never show up as sources

### Saved Torrents

The Torrents tab keeps magnet links the user pasted, independent of the catalog: a saved magnet is never matched to a Shikimori title.

- a link is accepted only when it has a BitTorrent info-hash (`xt=urn:btih:`, hex or base32); duplicates are detected by info-hash
- the name defaults to the magnet's `dn` and can be renamed later
- the list is stored locally in `shared_preferences` and sorted by last use
- on desktop, `Ctrl+V` on the tab opens the add form prefilled from the clipboard
- Watch and Download open the same file picker, player, and download routes as catalog sources (`/torrent/watch`, `/torrent/download`, `/player`); these routes are not tied to an anime id

## Player and Streaming

Playback uses:

- `libtorrent_flutter` to stream the selected torrent file through a local HTTP server (piece deadlines, no full download)
- `media_kit` and `media_kit_video` (mpv) to play the stream or a completed local download

Current behavior:

- streaming sessions are temporary; streamed pieces live in `<temp>/iris/stream`, are removed when the player closes, and the folder is wiped on every app start
- the Downloads tab shows one Cache total on every platform (Android: system app cache, which contains the stream folder; elsewhere: the stream folder) with a Clear action
- watch progress is stored per torrent info-hash and file index (`shared_preferences`), so streaming and a downloaded copy share it; playback resumes from the saved position with a Start over action, and a file counts as watched at 90%
- the file picker marks watched files and offers Continue / Up next; the Torrents tab, the anime page (Recently watched), the source list (You watched this) and the catalog (Continue watching) use the same history; an anime link is recorded only when playback was started from that anime's page
- the player can switch to the next file of the same torrent without re-adding it, and remembers the audio/subtitle choice per torrent
- player sessions of the same torrent share one native torrent (libtorrent keeps one per info-hash): reopening a release while the previous player is still closing reuses it, a newer stream stops the older session's stream, and the torrent with its stream cache is removed only when its last session ends
- one mpv player lives as long as the player page (`PlayerEngine`, owned by `PlayerCubit`); the video widget only renders it, so layout changes, full screen and switching files never recreate the player, and full screen survives a file switch. Before the next file opens the engine waits for mpv to go idle (and recreates the player if it does not) so the old stream connection is closed before libtorrent stops that stream
- on phones and tablets the player page shows the torrent's files as a supporting pane (Material canonical layout): beside the video on expanded and landscape windows (about 70/30, hidden with the app bar toggle), below a 16:9 video on portrait ones; the app bar shows the episode name and the release
- on desktop the player is immersive, in the spirit of streaming apps: the video fills the window, the controls lie over it and hide with the cursor after 3 s of playback (they stay while paused or hovered); while paused the frame dims and the anime (or the release's title without its tags), the episode and its place in the release are shown above the timeline; the time beside it counts down and a click switches it to the position and the file's length (the time above the bar shows only where hovering or dragging would seek); the episodes open from the buttons beside the timeline as a drawer on the right, headed by the full release name; the speed and buffer show at the top only while the stream stalls or its buffer runs thin, or always with "Technical details" on; full screen only switches the window
- Skip opening: the opening (or recap) comes from the file's chapters (`Opening`, `OP`, `Intro`, `ED`…), otherwise from [AniSkip](https://api.aniskip.com) (community times, looked up by the Shikimori/MyAnimeList id, the episode number parsed from the file name and the episode length; only when the anime is known from its page or the watch history). While it plays a Skip opening button appears like Next episode below; with no known opening a "+85 s" button sits in the controls during the first 5 minutes
- Next lives only in the player controls; from the ending's start when it is known, otherwise from 90% of a file (the watched threshold, i.e. the credits), a Next episode button appears inside the video, also in full screen, for 8 s and again on pointer movement or a tap, and stays once the file ends; playback never moves on by itself; resume is a snackbar with Start over that never pauses playback; the overlay shows speed and buffer, with full decoder diagnostics behind "Technical details" in player settings
- a session id that belongs to a completed download plays the local file instead of streaming
- streaming has priority over downloads: an active download of the same torrent goes back to the queue while the player is open and resumes afterwards
- libtorrent listens on port 6890 (TCP/uTP); if it is busy, libtorrent falls back to an OS-assigned port
- `libtorrent_flutter` is pinned to 1.7.8: 1.9.3+ (including 2.0.0) reports every torrent file as 0 bytes. Its decoded `TorrentState` is off by one with libtorrent 2.x, so only `isFinished`/`progress` and the error state are trusted

## Downloads

Downloads use:

- `libtorrent_flutter` to download the selected torrent file into app-internal storage
- an Android foreground service to keep the process active while minimized

Current behavior:

- only one download is active at a time; other items remain queued
- a download is marked completed only when libtorrent reports every wanted piece of the selected file
- opening the file picker for a torrent that is already downloading reuses that torrent; a queued item of the same torrent starts after the picker is closed
- pause and retry preserve already downloaded pieces
- completed files remain in app storage until the user deletes them
- app restart restores the durable queue and rechecks partial files
- Android may impose a time limit on very long `dataSync` foreground services on recent OS versions; interrupted items resume the next time the app starts

## Tech Stack

- Flutter + Dart
- `go_router`
- `flutter_bloc`
- `get_it`
- `dio`
- `media_kit`
- `libtorrent_flutter`
- `shared_preferences`

## Project Structure

The repository is organized by feature:

```text
lib/
  app/
  shared/
  entities/
  features/
    anime_list/
    anime_details/
    watch_sources/
    downloads/
    player/
    saved_torrents/
```

Inside each feature:

- `presentation/` contains widgets, pages, and state management
- `domain/` contains entities and repository contracts
- `data/` contains repository implementations, data sources, and mappers

## Development

Install dependencies:

```bash
flutter pub get
```

Run checks:

```bash
flutter analyze
flutter test
```

Run the app:

```bash
flutter run
```

Run on Windows desktop (requires Visual Studio 2022 with the "Desktop development with C++" workload):

```bash
flutter run -d windows
```

On Windows, downloads are stored under `%APPDATA%\com.kstkarus\iris\offline_downloads`, and the Android-only foreground service and storage stats are no-ops.

Adaptive layout follows the Material 3 window size classes (`lib/shared/widgets/adaptive/window_size_class.dart`): a navigation bar below 600 dp, a navigation rail from 600 dp, multi-column grids and two-pane details/downloads on wider windows. On desktop the player uses its own immersive controls (Space/K play-pause, ←/→ and J/L ∓10 s, ↑/↓ and the mouse wheel for volume, M mute, F full screen, N next episode, S skip, E episodes, Esc closes the drawer or leaves full screen; a click pauses, a double click switches full screen) and shows player settings as dialogs; the `mediacodec*` decoding modes are Android-only and map to `auto-safe` elsewhere.

Refresh generated files when needed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Status

This is an actively evolving private project focused on maintainability, clear boundaries, and a practical user experience for a small group of users.
