# Versioning and releases

For maintainers: how versions are numbered and how a release is published.

## Versioning

Versions follow [Semantic Versioning](https://semver.org), read from the user's side:

- **Patch** (1.2.**1**): fixes only.
- **Minor** (1.**3**.0): new features or noticeable changes; everything that worked keeps working.
- **Major** (**2**.0.0): changes that break something for existing users, such as a reset or migration of stored data, a raised minimum OS version or a dropped platform.

The version is raised per release, not per commit. Since commits follow [Conventional Commits](https://www.conventionalcommits.org), the weightiest commit since the last release decides: a `feat` makes a minor release, only `fix` commits a patch, and a breaking change a major one. Notable changes are recorded in [CHANGELOG.md](../CHANGELOG.md).

## Releasing

1. In `CHANGELOG.md`, move the entries under "Unreleased" into a new section `## [X.Y.Z] - YYYY-MM-DD` and update the links at the bottom.
2. Set `version: X.Y.Z+1` in `pubspec.yaml`. CI replaces the build number.
3. Commit, then tag and push:

   ```bash
   git tag vX.Y.Z
   git push origin main vX.Y.Z
   ```

The tag runs `.github/workflows/release.yml`:

- It first checks that the tag matches `pubspec.yaml` and that `CHANGELOG.md` has the version's section, and stops otherwise.
- It builds the APKs and the Windows archive. The tag becomes the version name and the run number the build number.
- It publishes them as a GitHub release, with the changelog section as the release text.

Repository secrets (Settings → Secrets and variables → Actions):

- **`ANDROID_DEBUG_KEYSTORE`** (required). Base64 of the keystore that signs release APKs. Releases are signed with a debug keystore generated on the maintainer's machine, not the publicly known Android test key; see `android/app/build.gradle.kts`.
  - Android installs an update only over the same signature. The workflow fails without this secret, and before publishing if the APK's certificate does not match `ANDROID_CERT_SHA256` in the workflow. A fork must set `ANDROID_CERT_SHA256` to its own key's SHA-256.
  - To encode it on Windows: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore"))`.
- **`SHIKIMORI_CONFIG`** (optional). The contents of `config/shikimori.json`. Without it, releases build with sign-in turned off.
