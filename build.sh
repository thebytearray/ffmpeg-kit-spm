#!/bin/bash
set -e

# Root of this Swift package (directory containing Package.swift).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_ROOT="${SCRIPT_DIR}"

# On failure, print the tail of ffmpeg-kit's build.log (local runs). In CI, the workflow prints this
# to avoid duplicating the same block in the log.
print_ffmpeg_kit_build_log_tail_on_failure() {
  local ec=$?
  [[ $ec -eq 0 ]] && exit 0
  if [[ "${CI:-}" == "true" ]]; then
    exit "$ec"
  fi
  local log="${WORK_DIR:-${PACKAGE_ROOT}/.tmp/ffmpeg-kit}/build.log"
  echo ""
  echo "======== Last 100 lines of FFmpeg-Kit build.log (${log}) — exit code ${ec} ========"
  if [[ -f "$log" ]]; then
    tail -n 100 "$log" 2>/dev/null || true
  else
    echo "(file not found — failure may have happened before FFmpeg-Kit created this log.)"
  fi
  echo "==================================================================================="
  exit "$ec"
}
trap print_ffmpeg_kit_build_log_tail_on_failure EXIT

# Release tag for this Swift package (GitHub Releases + Package.swift binary URLs).
FFMPEG_KIT_TAG="${FFMPEG_KIT_TAG:-v1.0.0}"

# Git branch, tag, or SHA inside ffmpeg-kit (see arthenica/ffmpeg-kit apple/README.md).
# Defaults to main; for a release matching FFMPEG_KIT_TAG, set e.g. FFMPEG_KIT_GIT_REF=full-gpl.v5.1.2.6.
FFMPEG_KIT_GIT_REF="${FFMPEG_KIT_GIT_REF:-main}"

FFMPEG_KIT_REPO="${FFMPEG_KIT_REPO:-https://github.com/arthenica/ffmpeg-kit}"
# Build tree (cloned on first run). Override with WORK_DIR if needed.
WORK_DIR="${WORK_DIR:-${PACKAGE_ROOT}/.tmp/ffmpeg-kit}"

if [ ! -f "${WORK_DIR}/ios.sh" ]; then
  echo "Cloning ffmpeg-kit into ${WORK_DIR}..."
  mkdir -p "$(dirname "${WORK_DIR}")"
  git clone "${FFMPEG_KIT_REPO}" "${WORK_DIR}"
fi

echo "Checking out ${FFMPEG_KIT_GIT_REF}..."
cd "${WORK_DIR}"
git fetch
git fetch --tags
git checkout "${FFMPEG_KIT_GIT_REF}"

# Used by patches/spm-apply-shine-l3mdct.sh (hooked into ios/tvos/macos.sh after source download).
export SPM_PATCH_ROOT="${PACKAGE_ROOT}"

# CMake 4.x (Homebrew): x265 vendored CMakeLists used OLD policies CMP0025/CMP0054 (unsupported)
# and had project() before cmake_minimum_required(). See patches/ffmpeg-kit-x265-cmake.patch.
X265_CMAKE_PATCH="${PACKAGE_ROOT}/patches/ffmpeg-kit-x265-cmake.patch"
if [ -f "${X265_CMAKE_PATCH}" ] && [ -f tools/patch/cmake/x265/CMakeLists.txt ]; then
  if grep -q 'cmake_policy(SET CMP0025 OLD)' tools/patch/cmake/x265/CMakeLists.txt; then
    echo "Applying x265 CMake patch for CMake 4.x..."
    patch -p1 --fuzz=0 < "${X265_CMAKE_PATCH}" || exit 1
  fi
fi

# C23 / GNU23 fixes for third-party sources that appear only after downloaded_library_sources
# (shine l3mdct.h, xvid encoder.h). Injected into ios/tvos/macos.sh — idempotent.
# See patches/spm-apply-after-download.sh
inject_spm_post_download_hook() {
  local plat_script="$1"
  [[ -f "${plat_script}" ]] || return 0
  if grep -q 'ffmpeg-kit-spm: post-download' "${plat_script}"; then
    return 0
  fi
  python3 - "${plat_script}" <<'PY' || exit 1
import sys
path = sys.argv[1]
marker = "# ffmpeg-kit-spm: post-download C/CMake patches (shine, xvid, cmake 4.x, -std=gnu23)"
with open(path) as f:
    content = f.read()
if "ffmpeg-kit-spm: post-download" in content:
    sys.exit(0)
needle = 'downloaded_library_sources "${ENABLED_LIBRARIES[@]}"\n'
if needle not in content:
    sys.stderr.write(f"inject: pattern not found in {path}\n")
    sys.exit(1)
hook = marker + '''
if [[ -n "${SPM_PATCH_ROOT:-}" ]] && [[ -f "${SPM_PATCH_ROOT}/patches/spm-apply-after-download.sh" ]]; then
  SPM_PATCH_ROOT="${SPM_PATCH_ROOT}" BASEDIR="${BASEDIR}" bash "${SPM_PATCH_ROOT}/patches/spm-apply-after-download.sh" || exit 1
fi

'''
with open(path, "w") as f:
    f.write(content.replace(needle, needle + hook, 1))
PY
}
for _spm_plat in ios tvos macos; do
  inject_spm_post_download_hook "${WORK_DIR}/${_spm_plat}.sh"
done

# Same patches when trees exist before platform scripts (local partial trees).
# Any apply_* in patches/spm-apply-after-download.sh no-ops if the target file is absent.
if [[ -d src ]] && [[ -f "${PACKAGE_ROOT}/patches/spm-apply-after-download.sh" ]]; then
  BASEDIR="${WORK_DIR}" SPM_PATCH_ROOT="${PACKAGE_ROOT}" bash "${PACKAGE_ROOT}/patches/spm-apply-after-download.sh" || exit 1
fi

echo "Install build dependencies..."
# Avoid concurrent `brew install` (e.g. two terminals running ./build.sh): Homebrew locks bottle downloads.
wait_for_brew_idle() {
  local n=0
  while pgrep -qf '/brew\.rb install' >/dev/null 2>&1; do
    echo "Another Homebrew install is running; waiting before continuing..."
    sleep 15
    n=$((n + 1))
    if [[ $n -gt 120 ]]; then
      echo "Timed out after ~30 minutes waiting for Homebrew. Close other brew installs and retry."
      exit 1
    fi
  done
}
wait_for_brew_idle
# No --overwrite: avoids unnecessary reinstall churn; run `brew upgrade` yourself if you need newer bottles.
BREW_DEPS=(autoconf automake libtool pkg-config curl git doxygen nasm cmake gcc gperf texinfo yasm bison autogen wget gettext meson ninja ragel groff gtk-doc docbook docbook-xsl libtasn1 gh)
BREW_MISSING=()
for _brew_pkg in "${BREW_DEPS[@]}"; do
  if ! brew list --formula "${_brew_pkg}" &>/dev/null; then
    BREW_MISSING+=("${_brew_pkg}")
  fi
done
if [[ ${#BREW_MISSING[@]} -gt 0 ]]; then
  if ! brew install "${BREW_MISSING[@]}"; then
    echo "brew install failed (often a transient lock). Waiting and retrying once..."
    wait_for_brew_idle
    sleep 5
    brew install "${BREW_MISSING[@]}"
  fi
fi

BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
BISON_BIN=""
if [ -n "${BREW_PREFIX}" ] && [ -d "${BREW_PREFIX}/opt/bison/bin" ]; then
  BISON_BIN="${BREW_PREFIX}/opt/bison/bin"
elif [ -d /usr/local/opt/bison/bin ]; then
  BISON_BIN="/usr/local/opt/bison/bin"
fi
XML_CATALOG=""
if [ -n "${BREW_PREFIX}" ] && [ -f "${BREW_PREFIX}/etc/xml/catalog" ]; then
  XML_CATALOG="${BREW_PREFIX}/etc/xml/catalog"
elif [ -f /usr/local/etc/xml/catalog ]; then
  XML_CATALOG="/usr/local/etc/xml/catalog"
fi
if [ -n "${XML_CATALOG}" ]; then
  export XML_CATALOG_FILES="${XML_CATALOG}"
fi
if [ -n "${BISON_BIN}" ]; then
  export PATH="${BISON_BIN}:${PATH}"
fi

# Full GPL: --full enables all external libraries; --enable-gpl allows GPL-licensed libs (x264, x265, etc.).
# Per apple/README.md, run ios/tvos/macos.sh then apple.sh to merge into bundle-apple-xcframework.
GPL_BUILD_FLAGS="-x --full --enable-gpl --disable-lib-srt --disable-lib-gnutls --disable-lib-lame"

echo "Building for iOS..."
./ios.sh ${GPL_BUILD_FLAGS}
echo "Building for tvOS..."
./tvos.sh ${GPL_BUILD_FLAGS}
echo "Building for macOS..."
./macos.sh ${GPL_BUILD_FLAGS}

echo "Bundling umbrella XCFrameworks (see apple/README.md)..."
./apple.sh

cd "${PACKAGE_ROOT}"

echo "Updating package file..."
PACKAGE_STRING=""
sed -i '' -e "s/let release =.*/let release = \"$FFMPEG_KIT_TAG\"/" Package.swift

XCFRAMEWORK_DIR="${WORK_DIR}/prebuilt/bundle-apple-xcframework"

rm -f "${XCFRAMEWORK_DIR}"/*.zip

for f in $(ls "${XCFRAMEWORK_DIR}")
do
    echo "Adding $f to package list..."
    PACAKGE="${XCFRAMEWORK_DIR}/${f}"
    ditto -c -k --sequesterRsrc --keepParent "${PACAKGE}" "${PACAKGE}.zip"
    PACKAGE_NAME=$(basename "$f" .xcframework)
    if command -v sha256sum >/dev/null 2>&1; then
      PACKAGE_SUM=$(sha256sum "${PACAKGE}.zip" | awk '{ print $1 }')
    else
      PACKAGE_SUM=$(shasum -a 256 "${PACAKGE}.zip" | awk '{ print $1 }')
    fi
    PACKAGE_STRING="$PACKAGE_STRING\"$PACKAGE_NAME\": \"$PACKAGE_SUM\", "
done

PACKAGE_STRING=$(basename "$PACKAGE_STRING" ", ")
sed -i '' -e "s/let frameworks =.*/let frameworks = [$PACKAGE_STRING]/" Package.swift

echo "Copying License..."
cp -f "${WORK_DIR}/LICENSE" ./

if [[ "${SPM_SKIP_RELEASE:-}" == "1" ]]; then
  echo "SPM_SKIP_RELEASE=1: skipping git commit, tag, push, and gh release."
  echo "XCFrameworks and Package.swift are updated locally."
  exit 0
fi

echo "Committing Changes..."
git add -u
git commit -m "Creating release for $FFMPEG_KIT_TAG"

echo "Creating Tag..."
git tag "$FFMPEG_KIT_TAG"
git push
git push origin --tags

echo "Creating Release..."
gh release create -p -d "$FFMPEG_KIT_TAG" -t "FFmpegKit SPM $FFMPEG_KIT_TAG" --generate-notes --verify-tag

echo "Uploading Binaries..."
for f in $(ls "${XCFRAMEWORK_DIR}")
do
    if [[ $f == *.zip ]]; then
        gh release upload "$FFMPEG_KIT_TAG" "${XCFRAMEWORK_DIR}/${f}"
    fi
done

gh release edit "$FFMPEG_KIT_TAG" --draft=false

echo "All done!"
