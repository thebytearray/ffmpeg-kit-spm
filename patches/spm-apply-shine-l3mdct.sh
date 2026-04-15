#!/usr/bin/env bash
# Called from ffmpeg-kit ios.sh / tvos.sh / macos.sh after downloaded_library_sources.
# BASEDIR and SPM_PATCH_ROOT must be set (build.sh exports SPM_PATCH_ROOT).
set -euo pipefail
PATCH="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-shine-l3mdct-h.patch"
HDR="${BASEDIR}/src/shine/src/lib/l3mdct.h"
[[ -f "${HDR}" ]] || exit 0
# Fixed prototype already present
if grep -q 'shine_mdct_initialise(shine_global_config' "${HDR}"; then
  exit 0
fi
if ! grep -Fq 'void shine_mdct_initialise();' "${HDR}"; then
  exit 0
fi

echo "Applying shine l3mdct.h prototype fix (GNU C23)..."
# CRLF breaks unified diff context; normalize for patch(1)
if grep -q $'\r' "${HDR}" 2>/dev/null; then
  perl -i -pe 's/\r\n/\n/g; s/\r/\n/g' "${HDR}"
fi

if [[ -f "${PATCH}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${PATCH}" ); then
  exit 0
fi

echo "patch(1) did not apply; using in-place substitution (same change as ffmpeg-kit-shine-l3mdct-h.patch)."
perl -i -pe 's/^void shine_mdct_initialise\(\);\s*$/void shine_mdct_initialise(shine_global_config *config);/' "${HDR}"

if grep -Fq 'void shine_mdct_initialise();' "${HDR}"; then
  echo "ERROR: could not fix ${HDR}" >&2
  exit 1
fi
