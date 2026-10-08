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

- endpoint: `https://shikimori.io/api/graphql`
- read-only integration
- user authorization is not connected yet
- every request carries `User-Agent: iris`, as Shikimori requires; replace it with the OAuth application name once one is registered
- requests are held on the client to Shikimori's limits (5 per second, 90 per minute); a `429` is retried once after `Retry-After`
- a title page lists the rest of the franchise under Related: prequel and sequel first, then the other relations by air date; commercials, promo videos and music clips are left out, and lists longer than four rows fold after three

### Watch Sources

The watch sources screen currently uses the public `nyaaapi` service:

- endpoint: `https://nyaaapi.onrender.com/nyaa`
- read-only lookup by every name of the anime (its main romaji name and its English title, without repeats): the service has no "or" and a release is found only by the name its group used, so each name is searched separately and the results are merged, each release once by its link; one failed name does not hide what the others found
- the service returns a single page of 75 per query, requested most-seeded first (`sort=seeders&order=desc`)
- only Nyaa's anime section is requested (`category=anime`), and anime music videos are dropped, so soundtracks, manga and AMVs never show up as sources
- when no name finds anything and a search failed, the screen shows an error with Retry instead of an empty list

### Saved Torrents

The Torrents tab keeps magnet links the user pasted, independent of the catalog: a saved magnet is never matched to a Shikimori title.

- a link is accepted only when it has a BitTorrent info-hash (`xt=urn:btih:`, hex or base32) and no malformed percent-encoding; duplicates are detected by info-hash
- the hex and base32 spellings of one info-hash are one torrent (keys use the 40-character hex form)
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
- progress saved under a base32 key by an earlier version is not matched
- the file picker marks watched files and offers Continue / Up next; the Torrents tab, the anime page (Recently watched), the source list (You watched this) and the catalog (Continue watching) use the same history; Continue watching leaves out files watched for less than a minute (a look at a release, not watching it), shows the latest title large and one more row, and folds the rest under a toggle (a single extra row is shown instead) so the catalog still starts on the first screen; an anime link is recorded only when playback was started from that anime's page
- the player can switch to the next file of the same torrent without re-adding it, and remembers the audio/subtitle choice per torrent
- player sessions of the same torrent share one native torrent (libtorrent keeps one per info-hash): reopening a release while the previous player is still closing reuses it, a newer stream stops the older session's stream, and the torrent with its stream cache is removed only when its last session ends
- a failed start keeps the prepared torrent, so Retry starts again without re-adding it
- one mpv player lives as long as the player page (`PlayerEngine`, owned by `PlayerCubit`); the video widget only renders it, so layout changes, full screen and switching files never recreate the player, and full screen survives a file switch. Before the next file opens the engine waits for mpv to go idle (and recreates the player if it does not) so the old stream connection is closed before libtorrent stops that stream
- on phones and tablets the player page shows the torrent's files as a supporting pane (Material canonical layout): beside the video on expanded and landscape windows (about 70/30, hidden with the app bar toggle), below a 16:9 video on portrait ones; the app bar shows the episode name and the release
- on desktop the player is immersive, in the spirit of streaming apps: the video fills the window, the controls lie over it and hide with the cursor after 3 s of playback (they stay while paused or hovered); while paused the frame dims and the anime (or the release's title without its tags), the episode and its place in the release are shown above the timeline; the time beside it counts down and a click switches it to the position and the file's length (the time above the bar shows only where hovering or dragging would seek); the episodes open from the buttons beside the timeline as a drawer on the right, headed by the full release name; the speed and buffer show at the top only while the stream stalls or its buffer runs thin, or always with "Technical details" on; full screen only switches the window
- Skip opening: the opening (or recap) comes from the file's chapters (`Opening`, `OP`, `Intro`, `ED`…), otherwise from [AniSkip](https://api.aniskip.com) (community times, looked up by the Shikimori/MyAnimeList id, the episode number parsed from the file name and the episode length; only when the anime is known from its page or the watch history). While it plays a Skip opening button appears like Next episode below; with no known opening a "+85 s" button sits in the controls during the first 5 minutes
- Next lives only in the player controls; from the ending's start when it is known, otherwise from 90% of a file (the watched threshold, i.e. the credits), a Next episode button appears inside the video, also in full screen, for 8 s and again on pointer movement or a tap, and stays once the file ends; playback never moves on by itself; resume is a snackbar (inside the video on desktop) with Start over that never pauses playback; it stays while the file starts, saying where playback will pick up, lets a Start over chosen before the first frame be taken back, and counts its 8 s from the first frame; a seek asked for before the file can take one is held until it can; the overlay shows speed and buffer, with full decoder diagnostics behind "Technical details" in player settings
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

Adaptive layout follows the Material 3 window size classes (`lib/shared/widgets/adaptive/window_size_class.dart`): text tabs at the bottom below 600 dp, a top bar with the mark and the sections in small text from 600 dp (Ctrl+1..3 switch sections), multi-column grids and two-pane details/downloads on wider windows. Top-level pages have no app bar: the navigation already names the section. Every page, the top bar and sub-page bars included, keeps to one frame (`AdaptiveContentWidth.page`, 1600 dp, centred) with its content left-aligned inside, so the left edge stays put between pages: the mark and the back arrow sit over it and the sections are centred in the bar. Narrower measures apply only inside the frame, to text (the description, Recently watched) and forms. On the title page the column beside the cover keeps to the cover's height: the title gets the height its Russian name, action and facts leave (`HeadlineColumn`), so a long title sets smaller instead of pushing the facts below the cover; only when even its smallest size does not fit does the column run longer. Recently watched names its action by what it does: Continue, Watch for a file only looked at (it starts from the beginning), Play next for a finished one.

Search in the catalog is a mode entered by focusing the field, so the page changes once and not with every keystroke: the catalog scrolls its header (Continue watching and the heading) away and its grid sits under the field. Typed queries develop their results over the catalog; an emptied field brings the catalog grid back without leaving search. Cancel (on phones), Escape, Back, or leaving an empty field ends the search, and the catalog returns to where it was. Results come from their own `AnimeSearchBloc` with the catalog's sort and filters, so the catalog is never reloaded for a search.

The visual language is a monochrome terminal style set at editorial scale (`lib/app/theme/app_theme.dart`): ink and bone surfaces, Geist Mono for text and figures and Geist for small chrome such as button labels (both bundled in `assets/fonts` under the OFL), square corners and a bevelled primary button. Each page has one large voice (`DisplayTitle`, sized to the space it has) against small text, with `>> LABEL` section headings, heavy block rules and block progress bars (`lib/shared/widgets/`); in a large bar the block where progress stops fills in Bayer order by its own share and the rest of the bar is a neutral checkerboard, all on whole device pixels. Icons are 7×7 pixel glyphs (`PixelIcon`), the anime cover on its page is a colour halftone (ordered dither, 5 levels per channel) that develops cell by cell into the original on tap (`DitheredImage`), and sheets, dialogs and menus open in the inverse theme. The only colour, a green signal (`ColorScheme.tertiary`), marks live state: playback and download progress, ongoing titles, the playing file. The player keeps the dark theme over video in both brightnesses (`OverVideoTheme`). Content that is still loading is faint pixel noise in the shape of the real layout (`AppSkeleton` over [skeletonizer](https://pub.dev/packages/skeletonizer), with the app's own `PixelNoiseEffect`); it shows only after a short delay and the content develops out of it in the same Bayer order as the halftone. A title opened from the catalog shows what the catalog already knows at once (`AnimeDetailsPreview`), so only its description waits. The same cell-by-cell dissolve (`DitherSwitcher`) swaps content that changes in place on purpose: catalog results and the catalog, the catalog heading when the order or filters change, the release list when it is re-sorted. It is not used for updates while typing, for local lists that appear at once (Torrents, Downloads), or for waits of unknown length that need words (preparing a torrent, buffering), which keep a spinner and a label. In the player the spinner is a 3×3 block loop (`BlockRunner`) in the play button's place, so it never reads as a level or a share loaded; the startup label names the stage, and if the start takes more than 5 s it adds the torrent's speed and peers (nothing for a source that moves no data, such as a downloaded file). No noise or dissolve is used in the player: before the first frame its shape is unknown, and full-screen noise reads as a lost signal. Motion is kept to state changes: halftones and covers develop in, progress bars move to new values, navigation markers travel, pages fade forward; all of it is instant when the system asks for reduced motion, and the noise holds still.

Regenerate localizations after editing `lib/l10n/*.arb` (output in `lib/l10n/generated`):

```bash
flutter gen-l10n
```

## Status

This is an actively evolving private project focused on maintainability, clear boundaries, and a practical user experience for a small group of users.
