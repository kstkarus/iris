# iris

`iris` is a Flutter mobile app for browsing anime, opening title details, finding watch sources, and playing episodes inside the app.

The project follows a feature-first structure with `FSD light` at the repository level and `clean arch` inside each feature.

## Current Product Scope

- browse anime titles
- open anime details
- search and filter the catalog
- find torrent-based watch sources
- choose a file when a torrent contains multiple playable videos
- play supported video files inside the app player
- customize subtitle appearance in the player

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

## Player

Playback currently uses:

- `libtorrent_flutter` to prepare a temporary torrent stream from a magnet link
- `media_kit` and `media_kit_video` to open the local stream inside the app

Current behavior:

- playback data is prepared through temporary torrent storage
- torrent sessions are disposed when the player session ends
- unsupported torrent contents are rejected with a user-facing error
- if a torrent contains multiple supported video files, the app opens a file selection step before playback

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
    player/
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

Refresh generated files when needed:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Status

This is an actively evolving private project focused on maintainability, clear boundaries, and a practical user experience for a small group of users.
