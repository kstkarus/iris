# iris

`iris` is a Flutter app (Android, iOS, Windows) for browsing anime and streaming episodes from torrents or online video servers in the in-app player. Downloading episodes for offline viewing is a secondary feature.

The project follows a feature-first structure with `FSD light` at the repository level and `clean arch` inside each feature.

## Current Product Scope

- browse anime titles
- open anime details
- search and filter the catalog
- find torrent-based watch sources, and online releases in many dubs (AniLibria, yummy_anime) above them
- save your own magnet links in the Torrents tab and stream or download them later
- choose a video file when a torrent contains multiple episodes
- stream the selected file in the in-app player
- optionally download a file for offline viewing and manage queued, active, paused, completed, and failed downloads
- continue an active download while the Android app is minimized
- view app, cache, and offline-content storage usage
- sign in with a Shikimori account on the Profile tab, and set an anime's status and episodes watched in its Shikimori list
- pick audio and subtitle tracks, customize subtitle appearance and decoding mode in the player

## Data Sources

### Anime Catalog

The app currently reads public anime data from the Shikimori GraphQL API:

- endpoint: `https://shikimori.io/api/graphql`
- the catalog is read anonymously; with a signed-in account the same client sends its token
- every request carries `User-Agent: iris`, as Shikimori requires: the name of the app's registered OAuth application
- requests are held on the client to Shikimori's limits (5 per second, 90 per minute); a `429` is retried once after `Retry-After`
- the filter sheet narrows the catalog by type, status, genre (genres and audiences shown, the 53 themes folded), season (this and the last broadcast quarter, this and the last year, decades, before 2000), age rating and episode length; signed in, also by the user's list (any statuses, or everything except Completed), which signing out drops. Genres are read from Shikimori once a session (`AnimeGenresRepository`); if they fail to load the section is left out
- a title page lists the rest of the franchise under Related: prequel and sequel first, then the other relations by air date; commercials, promo videos and music clips are left out, and lists longer than four rows fold after three
- once its details load, a title page adds the next episode of an airing title (`Episode 7 in 3 days`, today or tomorrow with the time), the studios, the genres and audiences (themes are left out) and the age rating; beside a wide cover these go below the cover rather than among the facts beside it, where the title is sized to fit and would shrink as they arrive. The dub teams Shikimori lists follow the description, folded after 12
- air dates show as much as Shikimori knows (the year, the month and year, or the day): it fills an unknown month or day with the first one

### Shikimori Account

The Profile tab (the fourth section) signs in with Shikimori's OAuth (authorization code flow, scope `user_rates`):

- the sign-in page opens in a browser tab on Android and the system sheet on iOS, which come back through the `iris://oauth/callback` redirect; on Windows and Linux it opens in the default browser, which comes back to a server the app runs at `http://127.0.0.1:43821/oauth/callback` (both redirects are registered with the application; the port is fixed because Shikimori compares redirects exactly). Making the app's window active again before the browser comes back cancels the sign-in. A random `state` ties the redirect to the sign-in that asked for it
- the tokens are kept in `flutter_secure_storage`; the account's id, nickname and avatar in preferences, so a session restored offline still shows whose it is
- the access token lasts a day: the Shikimori Dio (`ShikimoriAuthInterceptor`) renews it a minute before it runs out, or once after a `401`, with one renewal shared by requests that need it together; a renewal Shikimori refuses ends the session and the tab asks to sign in again, a network failure keeps it
- signing out forgets the session on the device; Shikimori has no endpoint to revoke it
- signed in, a title page has a My list section below the facts: the status (Add to list until it has one; the menu also takes it out of the list), once it is in the list `− 3 / 12 +` for the episodes watched, never past the total, and the score (10 down to 1, or none; scoring an anime not in the list adds it as completed); changes show at once and go to Shikimori one after another, the latest last, so quick taps neither race nor add the anime twice; a change Shikimori refuses falls back to what it keeps and says so. The entry is read through GraphQL (`Anime.userRate`) and written through `/api/v2/user_rates` (GraphQL has no mutations); Shikimori itself marks an anime completed when its last episode is checked (`lib/entities/user_rate/`)
- signed in, catalog covers carry the title's status in the list as a small inverse plate (`WATCHING 5/12`, `PLANNED`, `COMPLETED`); signing in or out reloads the catalog, while a session restored at launch has already signed the first page in
- signed in, the Profile tab shows the account (picture, name, a quiet grey Sign out) over a bar that stays pinned while the list scrolls: the List and Friends tabs and, beside them, a pop-up menu for the status shown (Watching, Planned, Completed, On hold, Dropped, Rewatching). The list runs the most recently changed first, 30 at a time as the page scrolls, in as many columns as the window fits: the cover, the names, episodes watched of the total and the score, and for an airing anime when its next episode comes (`today at 18:00`, `tomorrow at …`, `in 3 days`). A row opens the title page. Lists are read through GraphQL `userRates` (`lib/features/profile/`); a change made elsewhere shows in the rows at once, and an anime moved into the shown status reads it again
- an empty status says where a status is set (an anime's page); an empty Watching or Planned list also opens the catalog
- the Friends tab lists the account's Shikimori friends (`/api/users/:id/friends`), read when the tab is first opened; a friend opens their own list by status (`/user/:id`), to look at, with the same status menu
- signed in, a title page ends with the friends who have the anime in their lists: the status, episodes and score. Shikimori has no request for this, so the page asks about each of the first 30 friends in turn (`/api/v2/user_rates?user_id=…&target_id=…`), one at a time so other requests are not held behind them; friends and their entries are kept for the session. The section comes last because it arrives a while after the page, and is left out while it loads, if nobody has the anime, or if the friends do not load (`lib/entities/friend/`)
- signed in, an episode played to its ending (the start of the ending when it is known, otherwise 90 %) counts in the list (`MarkEpisodeWatched`): the count only grows, and a planned, on-hold, dropped or unlisted anime becomes watching (a rewatch or a completed anime keeps its status). An online release numbers its episodes, so it is marked at once with `Undo`; a torrent's number is read from the file name, so the player asks first (`Mark episode 5 on Shikimori?`). Nothing is marked without an anime (saved torrents) or a whole episode number (specials). The message is a notice inside the player
- every entry read or changed goes into one book above the router (`UserRateBookCubit`), and lists loaded earlier show it over their own data, so a change made anywhere shows everywhere at once; signing in as someone else empties it
- without `config/shikimori.json` (see Development) the tab says sign-in is not set up

### Watch Sources

The watch sources screen currently uses the public `nyaaapi` service:

- endpoint: `https://nyaaapi.onrender.com/nyaa`
- read-only lookup by every name of the anime (its main romaji name and its English title, without repeats): the service has no "or" and a release is found only by the name its group used, so each name is searched separately and the results are merged, each release once by its link; one failed name does not hide what the others found
- the service returns a single page of 75 per query, requested most-seeded first (`sort=seeders&order=desc`)
- only Nyaa's anime section is requested (`category=anime`), and anime music videos are dropped, so soundtracks, manga and AMVs never show up as sources
- when no name finds anything and a search failed, the screen shows an error with Retry instead of an empty list
- a catalog that cannot load keeps Continue watching above its error; an anime page that cannot load keeps what the list already knew (title, cover, facts and Choose source) and shows the error with Retry in place of the description

### Online Sources

The watch sources screen also looks the anime up on video servers, ported from [anicli-api](https://github.com/vypivshiy/anicli-api) 0.12.0:

- AniLibria, `https://aniliberty.top/api/v1`: its own dub, HLS up to 1080p
- yummy_anime, `https://api.yani.tv`: dozens of dubs and subtitles, each played through Kodik (HLS up to 720p) or Aksor (DASH up to 1080p, a few dubs); its CVH and Alloha players are not read
- both are read-only and need no account; every name of the anime is searched like the torrents, but a release is kept only when the site links it to the same Shikimori id, never by name alone
- online releases and torrents are two tabs of the page, text tabs with the current one marked as in the app's top bar, each with the whole height; wide windows set the dubs in columns; the tab chosen last opens, online the first time; a kind with nothing found takes its tab away, and the page is the other kind alone
- one row per dub, the dubs watched from first; when two sites carry the same dub, the copy with more episodes is kept (AniLibria on a tie)
- an episode the site gives no stream for is left out, and a release left with none is not offered; a special (12.5) keeps its own number in the picker and the same place in every dub
- a release opens its episodes in the same picker a torrent opens its files in, with Continue and next episode as for torrents; watch progress belongs to the anime's episode, so switching dub keeps the place
- an episode's stream links are asked for right before it plays (links expire), the better player first; buffering is mpv's; leaving the picker or the player drops a request still on its way; the stats overlay shows the decoder, without torrent speed or peers
- a link that expires while the episode plays or waits on pause is renewed: when mpv lets go of a file that had played, the link is asked for again and the episode reopens where it was (up to three times per episode; a file that never started fails as before); Try Again also opens the episode on a fresh link. Torrents and downloads keep their address
- a release row's Download button opens its episodes in the download picker; see Downloads
- the sites are asked at once and each one's dubs show as soon as it answers, developing out of noise rows; one waits at the end while another site still searches; when nothing is found the tabs dissolve; when the search fails the online tab says so with Retry
- `dart run tool/online_sources_smoke.dart [shikimoriId] [title...]` checks every site live
- animelib (ddos-guard), animego (HTTP 500), dreamcast (timeouts) and hdrezka (bot challenge, broken player) did not answer when this was built; animevost and sameband have no Shikimori ids, and animevost's dub comes through yummy_anime anyway

### Saved Torrents

The Torrents tab keeps magnet links the user pasted, independent of the catalog: a saved magnet is never matched to a Shikimori title.

- a link is accepted only when it has a BitTorrent info-hash (`xt=urn:btih:`, hex or base32) and no malformed percent-encoding; duplicates are detected by info-hash
- the hex and base32 spellings of one info-hash are one torrent (keys use the 40-character hex form)
- the name defaults to the magnet's `dn` and can be renamed later
- the list is stored locally in `shared_preferences` and sorted by last use
- on desktop, `Ctrl+V` (`⌘V` on macOS) on the tab opens the add form prefilled from the clipboard; the tab names the shortcut in the platform's spelling, also when the list is empty
- a row watches the torrent (or continues its last file); a watched torrent shows the episode read from the file name and how far into it on one line over its bar (`Episode 5 · 12:31 / 23:40`), or which episode it finished (`Episode 7 watched`, not the whole torrent); an unwatched one shows when it was added or last opened. Download, Rename, Copy link and Delete (set apart) are in the row's menu, which a long press or a right click also opens; it ends at its button and the row stays lit while it is open. Delete takes effect at once and offers Undo, which puts the torrent back as it was
- Watch and Download open the same file picker, player, and download routes as catalog sources (`/torrent/watch`, `/torrent/download`, `/player`); these routes are not tied to an anime id

## Player and Streaming

Playback uses:

- `libtorrent_flutter` to stream the selected torrent file through a local HTTP server (piece deadlines, no full download)
- `media_kit` and `media_kit_video` (mpv) to play the stream or a completed local download

Current behavior:

- streaming sessions are temporary; streamed pieces live in `<temp>/iris/stream`, are removed when the player closes, and the folder is wiped on every app start
- the Downloads tab shows the stream folder as Online viewing cache on every platform, with a line saying what it is and that clearing it keeps downloads, next to the Clear action that empties it; the rest of the Android app cache (posters) only counts in the total
- watch progress is stored per torrent info-hash and file index (`shared_preferences`), so streaming and a downloaded copy share it; playback resumes from the saved position with a Start over action, and a file counts as watched at 90%
- progress, track choices, saved torrents and downloads recorded under a base32 key by an earlier version are read under the hex key; where both spellings of one file or torrent were stored, they show once
- the file picker marks watched files and offers Continue / Up next; the Torrents tab, the anime page (Recently watched), the source list (You watched this) and the catalog (Continue watching) use the same history; Continue watching leaves out files watched for less than a minute (a look at a release, not watching it), shows the latest title large and one more row, and folds the rest under a toggle (a single extra row is shown instead) so the catalog still starts on the first screen; an anime link is recorded only when playback was started from that anime's page
- the player can switch to the next file of the same torrent without re-adding it, and remembers the audio/subtitle choice per torrent
- player sessions of the same torrent share one native torrent (libtorrent keeps one per info-hash): reopening a release while the previous player is still closing reuses it, a newer stream stops the older session's stream, and the torrent with its stream cache is removed only when its last session ends
- a failed start keeps the prepared torrent, so Retry starts again without re-adding it
- one mpv player lives as long as the player page (`PlayerEngine`, owned by `PlayerCubit`); the video widget only renders it, so layout changes, full screen and switching files never recreate the player, and full screen survives a file switch. Before the next file opens the engine waits for mpv to go idle (and recreates the player if it does not) so the old stream connection is closed before libtorrent stops that stream
- the player is immersive on every platform, in the spirit of streaming apps: the video fills the window, the controls lie over it and hide with the cursor after 3 s of playback (they stay while paused or hovered); while paused the frame dims and the anime (or the release's title without its tags), the episode and its place in the release are shown above the timeline; the time beside it counts down and a click switches it to the position and the file's length (the time above the bar shows only where hovering or dragging would seek); the episodes open from the buttons beside the timeline as a drawer on the right, headed by the full release name; while open the drawer takes the focus, keeps Tab inside it and is all a screen reader sees; the speed and buffer show at the top only while the stream stalls or its buffer runs thin, or always with "Technical details" on; full screen only switches the window
- on phones and tablets the player always plays in landscape (either way round) with the system bars hidden, and gives back free rotation and the app's edge-to-edge bars as it closes; the same controls are sized for a finger (48 dp targets, margins clear of a camera cutout), a tap on the video shows or hides them (also while paused), a touch on them keeps them 3 s longer, and the volume and full screen are left to the phone; Back closes the episodes drawer before it leaves the player; on the video, a double tap at either side (the outer 35 %) seeks 10 s back or forward and every tap after it in a row adds 10 s more, counted from where the row began (`+30` shows on that side), a tap in the middle shows or hides the controls at once while one at a side waits a moment for a second, a long press during playback plays at 2× until let go, a pinch out fills the screen with the video (cropping its edges, with mpv's subtitles kept above the cut) and a pinch in fits it back; touches that start in the system's edge-gesture areas are left to the system; the lock at the top right, opposite Back, hides everything over the video and lets no touch through (Back included) while playback goes on, a tap then shows Unlock for 3 s, and unlocking brings the controls back; a slider at the left, shown with the controls (dragging keeps them), sets the screen's brightness for the app only (`screen_brightness`, no permission), and the system's brightness comes back as the player closes
- Skip opening: the opening (or recap) comes from the file's chapters (`Opening`, `OP`, `Intro`, `ED`…), otherwise from [AniSkip](https://api.aniskip.com) (community times, looked up by the Shikimori/MyAnimeList id, the episode number parsed from the file name and the episode length; only when the anime is known from its page or the watch history). While it plays a Skip opening button appears like Next episode below; with no known opening a "+85 s" button is offered the same way during the first 5 minutes
- Next lives only in the player controls; from the ending's start when it is known, otherwise from 90% of a file (the watched threshold, i.e. the credits), a Next episode button appears inside the video, also in full screen, for 8 s on its own (counting down) and from then on exactly while the controls show (resting the pointer on it keeps them), and stays once the file ends; playback never moves on by itself; resume is a notice inside the video with Start over that never pauses playback; it stays while the file starts, saying where playback will pick up, lets a Start over chosen before the first frame be taken back, and counts its 8 s from the first frame; these plates over the video (resume, Skip opening, Next episode) show the time they have left as a thin bar along their bottom edge that shrinks until they go (going is all that happens), and hold full while the pointer rests on them or the focus is inside; a seek asked for before the file can take one is held until it can; an error mpv logs ends playback only when mpv lets go of the file within 2 s (a segment that did not load or a frame that did not decode is passed over); a failed file is paused, so nothing plays behind the error, and Try Again opens it where it stopped, seeking there if mpv opened it elsewhere; the overlay shows speed and buffer, with full decoder diagnostics behind "Technical details" in player settings
- the player has two panels, both a button away on every platform: Audio & subtitles holds only the tracks (side by side where there is room, with the codec where the name does not give it; subtitles are hidden by choosing Off), and Settings holds the playback speed (0.5× to 2×, kept for the player page, also across episodes) and then the subtitle look (size, colour, background and position as segmented choices) with the decoder, the ASS renderer and Technical details folded under Advanced, whose summary line shows the current decoder and renderer. Reset returns the look only and keeps the renderer, since switching it restarts the video; a custom colour, background or position warns that it replaces the release's styling. On desktop and tablets each panel opens as a popover of its button, above it at the bottom bar and below it at the top, without a title (the button names it) and without dimming the video; the button stays lit and the controls stay while it is open, a click outside or Escape closes it, and resizing the window closes it rather than leave it pointing at nothing. On narrow screens they are bottom sheets; the settings sheet dims the video only lightly, so the change can be seen on the subtitles behind
- a session id that belongs to a completed download plays the local file instead of streaming
- streaming has priority over downloads: an active download of the same torrent goes back to the queue while the player is open and resumes afterwards
- libtorrent listens on port 6890 (TCP/uTP); if it is busy, libtorrent falls back to an OS-assigned port
- `libtorrent_flutter` is pinned to 1.7.8: 1.9.3+ (including 2.0.0) reports every torrent file as 0 bytes. Its decoded `TorrentState` is off by one with libtorrent 2.x, so only `isFinished`/`progress` and the error state are trusted

## Downloads

Downloads use:

- `libtorrent_flutter` to download the selected torrent file into app-internal storage
- `dio` to download an online episode from its video server (`OnlineEpisodeDownloader`)
- an Android foreground service to keep the process active while minimized

Current behavior:

- only one download is active at a time, torrent file or online episode; other items remain queued
- an online episode is loaded in the best quality its server offers as HLS or mp4 (an mp4 first at the same quality); DASH (Aksor) is not loaded, so a dub served only in DASH, or as encrypted or byte-range HLS, fails with a message that it can only be watched online. HLS segments are glued into one file (MPEG-TS, or fragmented MP4 after its init segment) that mpv plays as it is; an mp4 is one file resumed with `Range`
- a paused, failed or interrupted online episode goes on from the next segment (or byte), in the quality it began in; a state file beside it records how far it got. A server that refuses a segment (403, 404, 410) is asked for a fresh link at once, other errors are tried four times with a growing wait first; if the episode's segment list changed, it starts over. A server that stays silent fails the download with "The video server stopped answering", and Retry picks up where it stopped
- an online episode has no peers; its size is an estimate (`~`) while it loads, scaled up from the play time loaded so far, and unknown before it starts. A finished one plays from disk and shares watch progress with the episode streamed online, whatever the dub
- a download is marked completed only when libtorrent reports every wanted piece of the selected file
- opening the file picker for a torrent that is already downloading reuses that torrent; a queued item of the same torrent starts after the picker is closed
- the file picker of a torrent that a player still holds (also one that is still closing) waits until the player lets go of it, since the player removes that torrent with its files; leaving the picker cancels the wait
- a torrent that fails or is removed while its metadata is awaited ends the wait at once, in the picker and in the player
- pause and retry preserve already downloaded pieces
- completed files remain in app storage until the user deletes them
- if the files cannot be removed (for example, a file still open elsewhere), the download stays in the list, stopped, and a message asks to delete it again
- app restart restores the durable queue and rechecks partial files
- the list puts active downloads first, then queued, paused, failed and done; one title's episodes stay together in episode order. A row names the title and the episode read from the file name (the file name only when it has none), its status and sizes: only the size while nothing has arrived, the time left and speed while downloading, or that there are no peers yet. Its one button does what the status calls for (Pause, Resume, Retry, or Watch for a done file, which a tap on the row also does); the same action and Delete are in the row's menu, which a long press, a right click or the Delete key also opens. Delete asks first and says how much downloaded data would be lost
- a failed download says why in words to act on (no space left, no access to the folder, the file gone, the download not starting); a screen reader hears a row as one sentence, its buttons name the episode, and a download that finishes or fails is announced
- with no downloads the tab says where episodes come from and opens the catalog
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
- `flutter_secure_storage`, `flutter_web_auth_2`

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
    auth/
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

Shikimori sign-in needs the OAuth application's id and secret, which stay out of git. Copy `config/shikimori.example.json` to `config/shikimori.json` (ignored), fill in the values from https://shikimori.io/oauth/applications and pass the file to every run or build (in Android Studio: Run configuration → Additional run args):

```bash
flutter run --dart-define-from-file=config/shikimori.json
```

Without it the app builds and runs, and the Profile tab says sign-in is not set up. The application must list `iris://oauth/callback` as a redirect URI and allow the `user_rates` scope. The secret ends up inside the built app, where it can be read out; that is accepted for an app shared among friends.

Run on Windows desktop (requires Visual Studio 2022 with the "Desktop development with C++" workload):

```bash
flutter run -d windows
```

On Windows, downloads are stored under `%APPDATA%\com.kstkarus\iris\offline_downloads`, and the Android-only foreground service and storage stats are no-ops.

Adaptive layout follows the Material 3 window size classes (`lib/shared/widgets/adaptive/window_size_class.dart`): text tabs at the bottom below 600 dp, a top bar with the mark and the sections in small text from 600 dp (Ctrl+1..4 switch sections), multi-column grids and two-pane details/downloads on wider windows. Top-level pages have no app bar: the navigation already names the section. Every page, the top bar and sub-page bars included, keeps to one frame (`AdaptiveContentWidth.page`, 1600 dp, centred) with its content left-aligned inside, so the left edge stays put between pages: the mark and the back arrow sit over it and the sections are centred in the bar. Narrower measures apply only inside the frame, to text (the description, Recently watched) and forms. On the title page the column beside the cover keeps to the cover's height: the title gets the height its Russian name, action and facts leave (`HeadlineColumn`), so a long title sets smaller instead of pushing the facts below the cover; only when even its smallest size does not fit does the column run longer. The title page's bar shows only the way back until the anime's name has wholly scrolled under it; then the name develops in the bar, and dissolves when it comes back into view. Recently watched names its action by what it does: Continue, Watch for a file only looked at (it starts from the beginning), Play next for a finished one.

Search in the catalog is a mode entered by focusing the field, so the page changes once and not with every keystroke: the catalog scrolls its header (Continue watching and the heading) away and its grid sits under the field. Typed queries develop their results over the catalog; an emptied field brings the catalog grid back without leaving search. Cancel (on phones), Escape, Back, or leaving an empty field ends the search, and the catalog returns to where it was. Results come from their own `AnimeSearchBloc` with the catalog's sort and filters, so the catalog is never reloaded for a search.

The visual language is a monochrome terminal style set at editorial scale (`lib/app/theme/app_theme.dart`): ink and bone surfaces, Geist Mono for text and figures and Geist for small chrome such as button labels (both bundled in `assets/fonts` under the OFL), square corners and a bevelled primary button; a button reached with the keyboard shows a 2 px outline (the primary button a stronger tint), which pointer and touch never bring up. Each page has one large voice (`DisplayTitle`, sized to the space it has) against small text, with `>> LABEL` section headings and block progress bars (`lib/shared/widgets/`); blocks always stand for a quantity (progress, loading), never for decoration; in a large bar the block where progress stops fills in Bayer order by its own share and the rest of the bar is a neutral checkerboard, all on whole device pixels. Icons are 7×7 pixel glyphs (`PixelIcon`), the anime cover on its page is a colour halftone (ordered dither, 5 levels per channel) that develops cell by cell into the original on tap (`DitheredImage`), and sheets, dialogs and menus open in the inverse theme; a sheet on a phone covers the whole window, navigation included, under a drag handle. The only colour, a green signal (`ColorScheme.tertiary`), marks live state: playback and download progress, ongoing titles, the playing file. The player keeps the dark theme over video in both brightnesses (`OverVideoTheme`). Content that is still loading is faint pixel noise in the shape of the real layout (`AppSkeleton` over [skeletonizer](https://pub.dev/packages/skeletonizer), with the app's own `PixelNoiseEffect`); it shows only after a short delay and the content develops out of it in the same Bayer order as the halftone. A title opened from the catalog shows what the catalog already knows at once (`AnimeDetailsPreview`). What its details will surely bring (the studio, genres and rating rows, the next episode of an airing title, the description) and the My list controls wait as noise in their shape, labels readable, so nothing above the reader moves when they land; sections that may well be empty (dubs, related titles, friends) show no noise and develop in below everything else when they arrive. One page, one loading language: no bars or spinners there. The same cell-by-cell dissolve (`DitherSwitcher`) swaps content that changes in place on purpose: catalog results and the catalog, the catalog heading when the order or filters change, the release list when it is re-sorted. It is not used for updates while typing, for local lists that appear at once (Torrents, Downloads), or for waits of unknown length that need words (preparing a torrent, buffering), which keep a spinner and a label. In the player the spinner is a 3×3 block loop (`BlockRunner`) in the play button's place, so it never reads as a level or a share loaded; the startup label names the stage, and if the start takes more than 5 s it adds the torrent's speed and peers, or that it has no peers yet (nothing for a downloaded file). A start is never cut short for a lack of peers: mpv waits for the data (its `network-timeout`), and only a first frame that takes over 45 s ends it. No noise or dissolve is used in the player: before the first frame its shape is unknown, and full-screen noise reads as a lost signal. Motion is kept to state changes: halftones and covers develop in, progress bars move to new values, navigation markers travel, pages fade forward, the fill of a segmented choice slides to the new option and a folded section unfolds and scrolls itself into view; all of it is instant when the system asks for reduced motion, and the noise holds still.

Regenerate localizations after editing `lib/l10n/*.arb` (output in `lib/l10n/generated`):

```bash
flutter gen-l10n
```

## Status

This is an actively evolving private project focused on maintainability, clear boundaries, and a practical user experience for a small group of users.
