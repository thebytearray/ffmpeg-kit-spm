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

apply_libvidstab_cmake() {
  local cm="${BASEDIR}/src/libvidstab/CMakeLists.txt"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-libvidstab-cmake.patch"
  [[ -f "${cm}" ]] || return 0
  if grep -qE 'cmake_minimum_required\s*\(\s*VERSION\s+3\.([5-9]|[1-9][0-9])' "${cm}"; then
    return 0
  fi
  if ! grep -q 'cmake_minimum_required' "${cm}"; then
    return 0
  fi

  echo "Applying libvidstab CMakeLists cmake_minimum_required >= 3.5 (CMake 4.x)..."
  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using sed fallback for libvidstab CMakeLists.txt."
  perl -i -pe 's/^cmake_minimum_required\s*\(\s*VERSION\s+2\.8\.5\s*\)/cmake_minimum_required(VERSION 3.5)/' "${cm}"
  if ! grep -qE 'cmake_minimum_required\s*\(\s*VERSION\s+3\.([5-9]|[1-9][0-9])' "${cm}"; then
    echo "ERROR: could not bump cmake_minimum_required in ${cm}" >&2
    return 1
  fi
  return 0
}

apply_snappy_cmake() {
  local cm="${BASEDIR}/src/snappy/CMakeLists.txt"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-snappy-cmake.patch"
  [[ -f "${cm}" ]] || return 0
  if ! grep -Fq 'cmake_minimum_required(VERSION 3.1)' "${cm}"; then
    return 0
  fi

  echo "Applying snappy CMakeLists cmake_minimum_required >= 3.5 (CMake 4.x)..."
  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using perl fallback for snappy CMakeLists.txt."
  perl -i -pe 's/cmake_minimum_required\(VERSION 3\.1\)/cmake_minimum_required(VERSION 3.5)/' "${cm}"
  if grep -Fq 'cmake_minimum_required(VERSION 3.1)' "${cm}"; then
    echo "ERROR: could not bump cmake_minimum_required in ${cm}" >&2
    return 1
  fi
  return 0
}

apply_chromaprint_cmake() {
  local cm="${BASEDIR}/src/chromaprint/CMakeLists.txt"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-chromaprint-cmake.patch"
  [[ -f "${cm}" ]] || return 0
  if ! grep -Fq 'cmake_minimum_required(VERSION 3.3)' "${cm}"; then
    return 0
  fi

  echo "Applying chromaprint CMakeLists cmake_minimum_required >= 3.5 (CMake 4.x)..."
  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using perl fallback for chromaprint CMakeLists.txt."
  perl -i -pe 's/cmake_minimum_required\(VERSION 3\.3\)/cmake_minimum_required(VERSION 3.5)/' "${cm}"
  if grep -Fq 'cmake_minimum_required(VERSION 3.3)' "${cm}"; then
    echo "ERROR: could not bump cmake_minimum_required in ${cm}" >&2
    return 1
  fi
  return 0
}

apply_soxr_cmake() {
  local cm="${BASEDIR}/src/soxr/CMakeLists.txt"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-soxr-cmake.patch"
  [[ -f "${cm}" ]] || return 0
  if ! grep -Fq 'cmake_minimum_required (VERSION 3.1 FATAL_ERROR)' "${cm}"; then
    return 0
  fi

  echo "Applying soxr CMakeLists cmake_minimum_required >= 3.5 (CMake 4.x)..."
  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using perl fallback for soxr CMakeLists.txt."
  perl -i -pe 's/cmake_minimum_required \(VERSION 3\.1 FATAL_ERROR\)/cmake_minimum_required (VERSION 3.5 FATAL_ERROR)/' "${cm}"
  if grep -Fq 'cmake_minimum_required (VERSION 3.1 FATAL_ERROR)' "${cm}"; then
    echo "ERROR: could not bump cmake_minimum_required in ${cm}" >&2
    return 1
  fi
  return 0
}

apply_libsamplerate_cmake() {
  local cm="${BASEDIR}/src/libsamplerate/CMakeLists.txt"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-libsamplerate-cmake.patch"
  [[ -f "${cm}" ]] || return 0
  if ! grep -Fq 'cmake_minimum_required(VERSION 3.1..3.18)' "${cm}"; then
    return 0
  fi

  echo "Applying libsamplerate CMakeLists cmake_minimum lower bound >= 3.5 (CMake 4.x)..."
  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using perl fallback for libsamplerate CMakeLists.txt."
  perl -i -pe 's/VERSION 3\.1\.\.3\.18/VERSION 3.5..3.18/' "${cm}"
  if grep -Fq 'cmake_minimum_required(VERSION 3.1..3.18)' "${cm}"; then
    echo "ERROR: could not bump cmake_minimum_required in ${cm}" >&2
    return 1
  fi
  return 0
}

apply_libsndfile_cmake() {
  local cm="${BASEDIR}/src/libsndfile/CMakeLists.txt"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-libsndfile-cmake.patch"
  [[ -f "${cm}" ]] || return 0
  if ! grep -Fq 'cmake_minimum_required (VERSION 3.1..3.18)' "${cm}"; then
    return 0
  fi

  echo "Applying libsndfile CMakeLists cmake_minimum lower bound >= 3.5 (CMake 4.x)..."
  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using perl fallback for libsndfile CMakeLists.txt."
  perl -i -pe 's/cmake_minimum_required \(VERSION 3\.1\.\.3\.18\)/cmake_minimum_required (VERSION 3.5..3.18)/' "${cm}"
  if grep -Fq 'cmake_minimum_required (VERSION 3.1..3.18)' "${cm}"; then
    echo "ERROR: could not bump cmake_minimum_required in ${cm}" >&2
    return 1
  fi
  return 0
}

apply_sdl_cmake() {
  local cm="${BASEDIR}/src/sdl/CMakeLists.txt"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-sdl-cmake.patch"
  [[ -f "${cm}" ]] || return 0
  if ! grep -Fq 'cmake_minimum_required(VERSION 2.8.11)' "${cm}"; then
    return 0
  fi

  echo "Applying SDL CMakeLists cmake_minimum_required >= 3.5 (CMake 4.x)..."
  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using perl fallback for SDL CMakeLists.txt."
  perl -i -pe 's/cmake_minimum_required\(VERSION 2\.8\.11\)/cmake_minimum_required(VERSION 3.5)/' "${cm}"
  if grep -Fq 'cmake_minimum_required(VERSION 2.8.11)' "${cm}"; then
    echo "ERROR: could not bump cmake_minimum_required in ${cm}" >&2
    return 1
  fi
  return 0
}

apply_jpeg_cmake() {
  local cm="${BASEDIR}/src/jpeg/CMakeLists.txt"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-jpeg-cmake.patch"
  [[ -f "${cm}" ]] || return 0
  if ! grep -Fq 'cmake_minimum_required(VERSION 2.8.12)' "${cm}"; then
    return 0
  fi

  echo "Applying libjpeg-turbo (jpeg) CMakeLists cmake_minimum_required >= 3.5 (CMake 4.x)..."
  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using perl fallback for jpeg CMakeLists.txt."
  perl -i -pe 's/cmake_minimum_required\(VERSION 2\.8\.12\)/cmake_minimum_required(VERSION 3.5)/' "${cm}"
  if grep -Fq 'cmake_minimum_required(VERSION 2.8.12)' "${cm}"; then
    echo "ERROR: could not bump cmake_minimum_required in ${cm}" >&2
    return 1
  fi
  return 0
}

apply_libpng_cmake() {
  local cm="${BASEDIR}/src/libpng/CMakeLists.txt"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-libpng-cmake.patch"
  [[ -f "${cm}" ]] || return 0
  if ! grep -Fq 'cmake_minimum_required(VERSION 3.1)' "${cm}"; then
    return 0
  fi

  echo "Applying libpng CMakeLists cmake_minimum / cmake_policy >= 3.5 (CMake 4.x)..."
  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using perl fallback for libpng CMakeLists.txt."
  perl -i -pe 's/cmake_minimum_required\(VERSION 3\.1\)/cmake_minimum_required(VERSION 3.5)/; s/cmake_policy\(VERSION 3\.1\)/cmake_policy(VERSION 3.5)/' "${cm}"
  if grep -Fq 'cmake_minimum_required(VERSION 3.1)' "${cm}"; then
    echo "ERROR: could not bump cmake_minimum_required in ${cm}" >&2
    return 1
  fi
  return 0
}

apply_tiff_cmake() {
  local cm="${BASEDIR}/src/tiff/CMakeLists.txt"
  local patch="${SPM_PATCH_ROOT}/patches/ffmpeg-kit-tiff-cmake.patch"
  [[ -f "${cm}" ]] || return 0
  if ! grep -Fq 'cmake_minimum_required(VERSION 2.8.11)' "${cm}"; then
    return 0
  fi

  echo "Applying libtiff CMakeLists cmake_minimum / cmake_policy >= 3.5 (CMake 4.x)..."
  if [[ -f "${patch}" ]] && ( cd "${BASEDIR}" && patch -p1 --fuzz=2 < "${patch}" ); then
    return 0
  fi

  echo "patch(1) did not apply; using perl fallback for tiff CMakeLists.txt."
  perl -i -pe 's/cmake_minimum_required\(VERSION 2\.8\.11\)/cmake_minimum_required(VERSION 3.5)/; s/cmake_policy\(VERSION 2\.8\.9\)/cmake_policy(VERSION 3.5)/' "${cm}"
  if grep -Fq 'cmake_minimum_required(VERSION 2.8.11)' "${cm}"; then
    echo "ERROR: could not bump cmake_minimum_required in ${cm}" >&2
    return 1
  fi
  return 0
}

apply_shine_l3mdct
apply_xvid_encoder_c23_bool
apply_libvidstab_cmake
apply_snappy_cmake
apply_chromaprint_cmake
apply_soxr_cmake
apply_libsamplerate_cmake
apply_libsndfile_cmake
apply_sdl_cmake
apply_jpeg_cmake
apply_libpng_cmake
apply_tiff_cmake
