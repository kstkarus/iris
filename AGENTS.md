# AGENTS.md

## Project overview
- This repository contains a Flutter mobile app for watching anime.
- Target audience: the owner of the app and a small circle of friends.
- Platforms: Android, iOS and Windows, all first-class. Layouts adapt between
  phone and desktop widths.
- Core product goals:
  - browse and filter the Shikimori catalog
  - open anime details and the user's Shikimori lists / friends
  - watch episodes from torrents or online sources in an in-app player
  - download torrents for offline viewing
  - keep watch progress
- Favor a clean, maintainable codebase over premature scale or heavy enterprise patterns.

## Tech stack
- Flutter + Dart, localization via ARB files + `flutter gen-l10n` (`lib/l10n/`)
- Routing: `go_router`
- State management: `flutter_bloc` (`Cubit` / `Bloc`)
- Persistent state: `shared_preferences` (JSON lists via `JsonListPreference`)
- Secure storage: `flutter_secure_storage` (Shikimori session)
- OAuth: `flutter_web_auth_2`
- Networking: `dio` (Shikimori REST + GraphQL, online sources)
- Dependency injection: `get_it`
- Models: plain immutable Dart classes, JSON parsed by hand in `data/` with
  `shared/utils/json_read.dart`; no code generation
- Video playback: `media_kit`, `media_kit_video`, `media_kit_libs_video`
- Screen brightness in the player (Android/iOS only, app-level, reset on
  leave): `screen_brightness` behind `shared/window/screen_brightness_control.dart`
- Torrents: `libtorrent_flutter` (version pinned on purpose, see `pubspec.yaml`)
- Loading placeholders: `skeletonizer`
- Remote images: `cached_network_image_ce` (disk cache), always through
  `shared/widgets/network_image.dart`
- Files: `path_provider`, `path`
- Formatting / dates: `intl`
- Testing: `flutter_test` with hand-written fakes (shared ones in `test/helpers/`),
  `fake_async` for timers instead of real sleeps

## Architecture
Use **FSD light** for repo organization and **clean architecture inside each feature**.

### High-level rules
- Organize code primarily by feature.
- Inside each feature, separate `presentation`, `domain`, and `data`.
- UI must not call API clients directly.
- `presentation` depends on `domain` only.
- `data` implements domain contracts and hides DTO / API details.
- Shared infrastructure belongs in `shared/`.
- Reusable business entities may live in `entities/` only when reused by multiple features.

### Repository shape
```text
lib/
  app/          router/, di/, theme/, bootstrap/
  l10n/         ARB files + generated localizations
  shared/       network/, online/, torrent/, storage/, theme/, window/,
                utils/, constants/, widgets/
  entities/     anime/, friend/, user_rate/, watch_progress/
  features/     each with presentation/, domain/, data/
    anime_list/       catalog, filters, continue watching
    anime_details/    title page
    characters/       a title's characters, character page
    auth/             Shikimori sign-in
    profile/          user lists, friends
    watch_sources/    torrent releases for a title
    online_sources/   online releases (AniLibria, yummy_anime)
    saved_torrents/   torrents the user added by hand
    downloads/        offline downloads
    player/           playback
    app_update/       new releases from GitHub, offered in the shell
```

### Shared helpers — reuse before writing new ones
- equality: `sameList` / `sameSet` / `sameMap` (`shared/utils/equality.dart`)
- JSON reading: `jsonMap`, `jsonString`, `jsonInt`… (`shared/utils/json_read.dart`), `enumByName`
- one-at-a-time async work: `SerialQueue`
- reduced motion: `motionDuration(context, duration)`
- sizes / rates: `formatByteSize`, `formatTransferRate`
- torrents: `isVideoFileName`, `unlessCancelled`
- network: `createJsonApiDio` / `createShikimoriDio`, `ShikimoriRestClient`,
  `ShikimoriGraphQlClient.queryList`, `searchAll`
- storage: `JsonListPreference`
- widgets: `FoldingList` (show more / less), `SourceFactsLine`, `watchedFirst`,
  `adaptiveColumnCount`, `status_views.dart` (loading / empty / error,
  `RetryView` / `InlineRetry` / `PagingFooter`), `PageFrame` (page body
  margins + width cap), `CheckedMenuItem` + `MenuController.toggle`,
  `TapRow` (tappable list row), `CaptionText` (small upper-case caption)

### Layer responsibilities
#### presentation/
- Flutter widgets, screens, dialogs, bottom sheets
- `Bloc` / `Cubit`
- UI mappers and view models if needed
- navigation triggers and UI side effects
- no `Dio`, no raw JSON, no DTOs

#### domain/
- entities used by business logic
- repository interfaces
- use cases when the logic is meaningful, reusable, or combines multiple repositories
- keep domain free from Flutter UI dependencies

#### data/
- repository implementations
- remote and local data sources
- DTOs and mappers
- API clients and persistence adapters
- map transport/storage errors into app-level failures before they reach UI

## State management rules
- Prefer `Cubit` for simple local screen logic.
- Use `Bloc` when there are multiple event types, async orchestration, or complex flows.
- Keep state immutable: `final` fields, `sealed` / `final class` hierarchies,
  value equality via `==` / `hashCode` (with the shared equality helpers).
- Persist only durable state, through a repository in `data/` backed by
  `shared_preferences` (or `flutter_secure_storage` for secrets), such as:
  - auth/session (secure storage)
  - player and catalog preferences worth restoring
  - saved torrents and downloads
  - watch progress
- Do **not** persist transient state, such as:
  - loading flags
  - snackbars / dialogs
  - temporary form validation messages
  - one-shot navigation effects

## Routing rules
- Use `go_router` as the single routing solution.
- Define routes centrally in `app/router/`.
- Keep route names and paths stable and readable.
- Put route guards / redirect logic near router config, not inside widgets.
- Prefer typed argument wrappers or small route helper methods over passing loose maps.

## Networking rules
- Use `dio` through shared clients configured in `shared/network/`.
- Keep interceptors, auth headers, logging, and retry behavior out of UI.
- Never parse API responses inside widgets or blocs.
- DTOs must stay in `data/`.
- Domain and presentation layers must not depend on raw response schemas.

## Dependency injection rules
- Register dependencies in `app/di/`.
- Inject abstractions into blocs/use cases/repositories whenever practical.
- Avoid service locator calls deep inside widgets when constructor injection is possible.
- Do not introduce a second DI framework without a strong reason.

## Media rules
- Use `media_kit` for playback.
- Keep playback coordination inside the `player` feature.
- Preserve screen wake state only during active video playback.
- Treat player lifecycle carefully: pause/resume/dispose explicitly.
- One player layout on every platform: the video fills the screen under the
  app's own immersive controls (no media_kit controls). `PlayerInputMode`
  (`pointer` on desktop, `touch` on Android/iOS) only sizes them and drops
  what a phone does itself (volume, full screen).
- On phones and tablets the player is always landscape and immersive:
  `PlayerScreenMode` (`shared/window/player_screen_mode.dart`, from DI) enters
  on open and on app resume, and leaves (free rotation, edge-to-edge) as the
  page pops. Desktop gets `NoPlayerScreenMode` and switches window full
  screen from the controls.

### Playback startup contract (torrent -> mpv)
This contract is binding. Reference implementations: peerflix, WebTorrent, libtorrent
streaming docs (`https://www.libtorrent.org/streaming.html`). Rationale: format-sniffing
in the Dart layer duplicates mpv's own probe, adds latency, competes with mpv for the
single local libtorrent HTTP connection, and produces false negatives on legitimate
containers (WebM, non-standard `ftyp` brands, FLV, OGG, MOV variants).

1. **Never gate playback startup on a Dart-side format probe.**
   The HTTP probe (`PlaybackStreamProbe` / `looksLikePlayableMedia`) is **diagnostics-only**:
   run it in the background, log the result, never block `PlaybackLaunchReadyUpdateModel`
   on it, never fail startup because of it.
2. **Stream-readiness is the torrent engine and local HTTP server's responsibility.**
   Startup may emit the local stream URL immediately after `startStream`; the local
   HTTP server must hold byte-range responses until requested pieces are available.
   Do not paper over missing piece readiness with a Dart-side buffer% heuristic.
3. **Fast-fail for a broken URL is a separate concern from format detection.**
   If we need it, implement it as a short connectivity check (single attempt, ~1-2s,
   HTTP status only, no body sniffing). Format heuristics are not a substitute.
4. **Buffering is delegated to mpv via media_kit.**
   Configure `--cache=yes`, `--cache-secs`, `--demuxer-readahead-secs`,
   `--network-timeout` rather than implementing wait loops in Dart.
5. **UI buffering state comes from `Player.stream.buffering`** (plus optional torrent
   progress from the adapter), never from the probe.
6. **Probe lifecycle must follow the session.** Cancel the background probe on
   `disposePlayback` and on launch cancellation; ignore late results from disposed
   sessions (covered by tests in `libtorrent_player_data_source_test.dart`).

### Decoding & rendering performance
This contract is binding for the in-app player.

1. **Hardware decoding is the default.** Create `VideoController` with an explicit
   `VideoControllerConfiguration(hwdec: 'auto-safe', enableHardwareAcceleration: true)`.
   This matches the current `media_kit_video` Android default, but keeps our behavior
   stable across package upgrades.
2. **Expose a user override for decoding mode.** Supported modes are `auto-safe`,
   `mediacodec`, `mediacodec-copy`, and `no`. Users should change this only for
   device-specific playback problems.
3. **Do not force decoders globally through `vd`.** Keep software fallback thread
   usage explicit with `vd-lavc-threads=0`, but do not add a global AV1 decoder chain
   without a separate measured iteration.
4. **Buffering is configured at mpv level.** Keep `cache=yes`, `cache-pause=yes`,
   `cache-pause-initial=yes`, `demuxer-max-bytes`, and `demuxer-max-back-bytes`.
   Also set `cache-secs=30`, `demuxer-readahead-secs=20`, `network-timeout=60`,
   and `cache-pause-wait=3`.
5. **Torrent streaming is deadline/priority-driven, not sequential-only.** The
   `libtorrent_flutter` integration relies on piece deadlines and critical startup
   pieces; do not reintroduce a sequential-only requirement.
6. **Overlay diagnostics must show real decoder state.** Surface `hwdec-current`,
   `current-vo`, `current-tracks/video/codec`, `current-tracks/video/decoder`, and
   `current-tracks/video/decoder-desc`. Missing or invalid diagnostic values must be
   ignored without breaking playback UI.

## Error handling rules
- Convert low-level exceptions into app-specific failures.
- UI should react to user-meaningful states, not `DioException` or raw stack traces.
- Show concise, user-facing error messages.
- Log useful debug information without leaking sensitive data.

## Security and storage
- Store tokens and sensitive user data in `flutter_secure_storage`.
- Do not store secrets in source code.
- Do not commit API keys, tokens, or private endpoints.
- If a secret is needed for local development, document it in `README.md` and use ignored local config.

## Coding conventions
- Favor small files and focused classes.
- Prefer explicit names over clever abstractions.
- Keep widgets composable and shallow where possible.
- Keep functions short and single-purpose.
- Avoid premature generic base classes.
- Add comments only when intent is not obvious from code.
- Do not introduce new dependencies unless they solve a real repeated problem.

## Commands
Run these before calling work done when relevant:

```bash
flutter pub get
flutter analyze
flutter test
```

When ARB files in `lib/l10n/` change, run:

```bash
flutter gen-l10n
```

Useful development commands:

```bash
dart format .
flutter run
```

## Definition of done
A task is done when all of the following are true when applicable:
- code matches the feature-first architecture
- no layer violations were introduced
- formatting is clean
- `flutter analyze` passes
- relevant tests were added or updated
- `flutter test` passes
- localizations are regenerated if ARB files changed
- public behavior changes are reflected in `README.md` when necessary

## Git workflow
- Use Conventional Commits: `type(scope): description`
- Common types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
- Keep commits small and meaningful.
- For larger features, prefer feature branches.
- Keep `main` in a runnable state.
- Do not commit `windows/flutter/generated_plugin*` changes that a local
  build regenerates; restore them before committing.

## What to avoid
- Do not put business logic in widgets.
- Do not couple blocs directly to `Dio`.
- Do not expose DTOs outside `data/`.
- Do not create a use case for every trivial getter.
- Do not over-engineer abstractions for a small app.
- Do not add large docs inside this file; link out to `docs/` instead.

## Documentation map
Keep this file short. Durable details go into:
- `README.md` for setup and quickstart
- `docs/private/` (git-ignored) for the owner's roadmaps and decision notes
- if shared docs become necessary: `docs/architecture.md`, `docs/decisions/`

## Agent behavior expectations
When working in this repository:
- preserve the chosen stack unless a change is justified
- prefer minimal, local changes over broad rewrites
- explain architecture-impacting changes clearly
- update tests and docs when behavior changes
- ask for confirmation before adding a major dependency or replacing a core pattern
