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
- Before any platform build, the reusable `.github/workflows/checks.yml` workflow runs `flutter analyze --no-pub` and `flutter test --no-pub` on Windows with the pinned Flutter version. A failed check stops the release builds. The same checks run on pull requests and pushes to `main`.
- It builds the APKs, the Windows archive and per-user installer, and an unsigned iOS IPA on macOS. The tag becomes the version name and the run number the build number.
- It publishes them as a GitHub release, with the changelog section as the release text.

Windows provides both `iris-X.Y.Z-windows-x64.zip` and `iris-X.Y.Z-windows-x64-setup.exe`. The per-user installer uses Inno Setup 6.7.3, whose official release asset is verified before the CI job runs its compiler. It installs under the current user's Programs folder without requesting administrator privileges. Install and uninstall leave the existing app-support data intact. The installer is not Authenticode-signed.

For a local installer build, build Windows first, set `IRIS_VERSION` to the build's version, then run `ISCC.exe windows/installer/iris.iss`; the output goes to `dist/`. Run the native path/startup-mutex check from a Visual Studio Native Tools PowerShell prompt with `./windows/runner/run_app_update_native_check.ps1`.

The iOS job runs `flutter build ios --release --no-codesign`, then packages `Runner.app` inside `Payload/` as `iris-X.Y.Z-ios-unsigned.ipa`. The IPA is also available in the run's `ios-unsigned` artifact. Flutter 3.47.4 migrates the project's older deployment target to iOS 15 during the build, so these artifacts require iOS 15 or later. No Apple signing secrets are needed; the IPA must be signed with the user's certificate and provisioning profile before installation on an iPhone or iPad (see the [Flutter iOS deployment guide](https://docs.flutter.dev/deployment/ios)). It is not an App Store or TestFlight upload. All three platform builds must succeed before the release is published.

Repository secrets (Settings → Secrets and variables → Actions):

- **`ANDROID_DEBUG_KEYSTORE`** (required). Base64 of the keystore that signs release APKs. Releases are signed with a debug keystore generated on the maintainer's machine, not the publicly known Android test key; see `android/app/build.gradle.kts`.
  - Android installs an update only over the same signature. The workflow fails without this secret, and before publishing if the APK's certificate does not match `ANDROID_CERT_SHA256` in the workflow. A fork must set `ANDROID_CERT_SHA256` to its own key's SHA-256.
  - To encode it on Windows: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\.android\debug.keystore"))`.
- **`SHIKIMORI_CONFIG`** (optional). The contents of `config/shikimori.json`. Without it, releases build with sign-in turned off.
