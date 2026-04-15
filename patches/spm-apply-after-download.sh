#!/usr/bin/env bash
# Run from ffmpeg-kit ios/tvos/macos.sh right after downloaded_library_sources.
# BASEDIR and SPM_PATCH_ROOT must be set (build.sh exports SPM_PATCH_ROOT).
set -euo pipefail

apply_shine_l3mdct() {
  local hdr="${BASEDIR}/src/shine/src/lib/l3mdct.h"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-shine-l3mdct-h.patch"
  [[ -f "${hdr}" ]] || return 0
  if grep -q 'shine_mdct_initialise(shine_global_config' "${hdr}"; then
    return 0
  fi
  if ! grep -Fq 'void shine_mdct_initialise();' "${hdr}"; then
    return 0
  fi

  echo "Applying shine l3mdct.h prototype fix (GNU C23)..."
  if grep -q $'\r' "${hdr}" 2>/dev/null; then
    perl -i -pe 's/\r\n/\n/g; s/\r/\n/g' "${hdr}"
  fi

  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using in-place substitution for shine l3mdct.h."
  perl -i -pe 's/^void shine_mdct_initialise\(\);\s*$/void shine_mdct_initialise(shine_global_config *config);/' "${hdr}"

  if grep -Fq 'void shine_mdct_initialise();' "${hdr}"; then
    echo "ERROR: could not fix ${hdr}" >&2
    return 1
  fi
  return 0
}

apply_xvid_encoder_c23_bool() {
  local hdr="${BASEDIR}/src/xvidcore/xvidcore/src/encoder.h"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-xvid-encoder-h-c23-bool.patch"
  [[ -f "${hdr}" ]] || return 0
  if grep -q 'ffmpeg-kit-spm: xvid C23 bool' "${hdr}"; then
    return 0
  fi
  if ! grep -Fq 'typedef int bool;' "${hdr}"; then
    return 0
  fi

  echo "Applying xvid encoder.h C23 bool fix..."
  if grep -q $'\r' "${hdr}" 2>/dev/null; then
    perl -i -pe 's/\r\n/\n/g; s/\r/\n/g' "${hdr}"
  fi

  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using Python fallback for xvid encoder.h."
  python3 - "${hdr}" <<'PY' || return 1
import sys
from pathlib import Path
p = Path(sys.argv[1])
t = p.read_text()
marker = "/* ffmpeg-kit-spm: xvid C23 bool */"
if marker in t:
    sys.exit(0)
old = "\ntypedef int bool;\n"
if old not in t:
    sys.stderr.write("xvid fallback: typedef int bool not found\n")
    sys.exit(1)
new = (
    "\n"
    + marker
    + "\n#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 202311L\n"
    + "#include <stdbool.h>\n#else\ntypedef int bool;\n#endif\n"
)
p.write_text(t.replace(old, new, 1))
PY

  if grep -Fq 'typedef int bool;' "${hdr}" && ! grep -q 'stdbool.h' "${hdr}"; then
    echo "ERROR: could not fix ${hdr} for C23 bool" >&2
    return 1
  fi
  return 0
}

apply_shine_l3mdct
apply_xvid_encoder_c23_bool
