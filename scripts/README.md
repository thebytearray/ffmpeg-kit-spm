# Scripts

[`build/ffmpeg-kit-build.sh`](build/ffmpeg-kit-build.sh) clones and checks out ffmpeg-kit, injects hooks, installs Homebrew dependencies, runs `ios.sh`, `tvos.sh`, `macos.sh`, and `apple.sh`, refreshes `Package.swift`, and optionally runs `gh` for a release. Root [`build.sh`](../build.sh) sources it; do not run this file directly (it expects `PACKAGE_ROOT`).

Common environment: `PACKAGE_ROOT` (set by `build.sh`), `WORK_DIR` (default `.tmp/ffmpeg-kit`), `SPM_PATCH_ROOT` (repo root for `patches/`), `SPM_SKIP_RELEASE=1` to skip git and gh after building, `FFMPEG_KIT_GIT_REF` and `FFMPEG_KIT_TAG`.

For the GitHub Actions workflow that runs the same path, see "Publishing via GitHub Actions" in the root [`README.md`](../README.md).
