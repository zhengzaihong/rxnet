# Releasing RxNet Plus

The GitHub Actions workflow at `.github/workflows/ci.yml` handles verification,
packaging and publishing.

## Required GitHub secret

Add a repository secret:

| Secret | Purpose |
| --- | --- |
| `PUB_DEV_TOKEN` | pub.dev API token with package publish permission |

`GITHUB_TOKEN` is provided by Actions automatically and is used to create the
GitHub Release/tag.

If `PUB_DEV_TOKEN` is missing, the publish job emits a warning and skips
pub.dev publishing/GitHub Release instead of failing the build.

## Release flow

1. Update `version` in `pubspec.yaml`.
2. Add a matching `## X.Y.Z` section to `CHANGELOG.md`.
3. Update README version references and add a migration guide if behavior changed.
4. Commit and push to `master`.

The workflow runs:

- **verify** — `flutter pub get`, `flutter analyze`, `flutter test --coverage`,
  full Web build; uploads the Web demo artifact.
- **windows-build** — builds the Windows example in release mode
  (`continue-on-error`, so a runner/toolchain issue does not block publishing).
- **publish** — only for `master` pushes or manual dispatch:
  1. Reads the version from `pubspec.yaml`.
  2. Fails if `CHANGELOG.md` has no `## <version>` section.
  3. Checks `https://pub.dev/api/packages/rxnet_plus` via `jq`.
  4. Skips if the version is already published.
  5. Runs `flutter pub publish --dry-run`.
  6. Stores the token with `dart pub token add` and publishes with
     `flutter pub publish --force`.
  7. Creates GitHub tag/release `v<version>` and attaches the Web demo zip.

## Manual release / re-run

Use **Actions → CI & Release → Run workflow**, select `master`.

If the version already exists on pub.dev, the publish step is skipped. Bump the
version first if you need to publish again.

## Local preflight

```bash
flutter pub get
flutter analyze
flutter test
flutter build web --no-pub --target=lib/rxnet_web_smoke.dart # from example/
flutter build windows --release --no-pub                     # from example/
flutter pub publish --dry-run
```

## GitHub Pages demo

Enable **Settings → Pages → Build and deployment → Source: GitHub Actions**
once in the repository.

On every `master` push the `deploy-pages` job publishes the example Web build
to:

`https://zhengzaihong.github.io/rxnet/`

The CI Web build uses `--base-href /rxnet/` so assets resolve under the project
site path. If the repository is renamed or a custom domain is used, update that
flag in `.github/workflows/ci.yml`.

The job is marked `continue-on-error`; a Pages misconfiguration will not block
pub.dev publishing or the GitHub Release.

## Notes

- Never commit the pub.dev token.
- The Android example APK is not built in CI yet because the example project
  currently uses an AGP9 `android.newDsl` configuration that fails locally.
  Fix the example toolchain first, then add an Android job.
- Wasm builds are limited upstream by `dio_web_adapter`'s `dart:html` usage.
- Keep `doc/` (not `docs/`) and `.pubignore` maintained; see the publish
  checklist in the project documentation.