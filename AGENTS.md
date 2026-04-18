# AGENTS.md

## Project overview
- This repository contains a Flutter mobile app for watching anime.
- Target audience: the owner of the app and a small circle of friends.
- Primary platforms: Android and iOS.
- Core product goals:
  - browse anime titles
  - open anime details
  - watch episodes in an in-app player
  - search and filter titles
  - keep favorites and basic watch progress
- Favor a clean, maintainable codebase over premature scale or heavy enterprise patterns.

## Tech stack
- Flutter + Dart
- Routing: `go_router`
- State management: `flutter_bloc`
- Persistent state: `hydrated_bloc` (selective use only)
- Networking: `dio`
- Dependency injection: `get_it`
- Models and unions: `freezed`, `freezed_annotation`, `json_serializable`, `json_annotation`
- Video playback: `media_kit`, `media_kit_video`
- Images: `cached_network_image`
- Secure storage: `flutter_secure_storage`
- Local formatting / dates: `intl`
- Optional app helpers: `path_provider`, `connectivity_plus`, `wakelock_plus`
- Testing: `flutter_test`, `bloc_test`, `mocktail`

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
  app/
    router/
    di/
    theme/
    bootstrap/
  shared/
    network/
    storage/
    utils/
    constants/
    widgets/
  entities/
    anime/
    episode/
    user/
  features/
    auth/
      presentation/
      domain/
      data/
    anime_list/
      presentation/
      domain/
      data/
    anime_details/
      presentation/
      domain/
      data/
    player/
      presentation/
      domain/
      data/
    search/
      presentation/
      domain/
      data/
    favorites/
      presentation/
      domain/
      data/
    profile/
      presentation/
      domain/
      data/
```

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
- Keep state immutable.
- Use `Freezed` for bloc states/events where it improves clarity.
- Persist only durable state with `hydrated_bloc`, such as:
  - auth/session markers
  - selected filters worth restoring
  - favorites metadata if chosen for UX
  - last watched episode / playback progress summary
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

When generated models change, run:

```bash
dart run build_runner build --delete-conflicting-outputs
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
- generated code is refreshed if needed
- public behavior changes are reflected in `README.md` or `docs/architecture.md` when necessary

## Git workflow
- Use Conventional Commits: `type(scope): description`
- Common types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`
- Keep commits small and meaningful.
- For larger features, prefer feature branches.
- Keep `main` in a runnable state.

## What to avoid
- Do not put business logic in widgets.
- Do not couple blocs directly to `Dio`.
- Do not expose DTOs outside `data/`.
- Do not create a use case for every trivial getter.
- Do not over-engineer abstractions for a small app.
- Do not add large docs inside this file; link out to `docs/` instead.

## Documentation map
Keep this file short. If the repository grows, move durable details into:
- `README.md` for setup and quickstart
- `docs/architecture.md` for deeper architectural rules
- `docs/decisions/` for major technical decisions
- `docs/features/` for feature notes only when they become necessary

## Agent behavior expectations
When working in this repository:
- preserve the chosen stack unless a change is justified
- prefer minimal, local changes over broad rewrites
- explain architecture-impacting changes clearly
- update tests and docs when behavior changes
- ask for confirmation before adding a major dependency or replacing a core pattern
