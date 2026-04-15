#!/usr/bin/env bash
# Called from ffmpeg-kit ios.sh / tvos.sh / macos.sh right after downloaded_library_sources.
# BASEDIR and SPM_PATCH_ROOT must be set (build.sh exports SPM_PATCH_ROOT before running platform scripts).
set -euo pipefail
PATCH="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-shine-l3mdct-h.patch"
HDR="${BASEDIR}/src/shine/src/lib/l3mdct.h"
[[ -f "${PATCH}" ]] || exit 0
[[ -f "${HDR}" ]] || exit 0
if ! grep -q 'void shine_mdct_initialise();' "${HDR}"; then
  exit 0
fi
echo "Applying shine l3mdct.h patch (GNU C23 prototype)..."
( cd "${BASEDIR}" && patch -p1 --fuzz=0 < "${PATCH}" )
