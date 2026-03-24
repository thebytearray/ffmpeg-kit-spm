#!/bin/sh
set -e

FFMPEG_KIT_TAG="${FFMPEG_KIT_TAG:-full-gpl.v5.1.2.6}"
FFMPEG_KIT_CHECKOUT="origin/develop"
#FFMPEG_KIT_CHECKOUT="origin/tags/$FFMPEG_KIT_TAG"

FFMPEG_KIT_REPO="https://github.com/thebytearray/ffmpeg-kit"
WORK_DIR=".tmp/ffmpeg-kit"

if [[ ! -d $WORK_DIR ]]; then
  echo "Cloning ffmpeg-kit repository..."
  mkdir .tmp/ || true
  cd .tmp/
  git clone $FFMPEG_KIT_REPO
  cd ../
fi

echo "Checking out $FFMPEG_KIT_CHECKOUT..."
cd $WORK_DIR
git fetch
git fetch --tags
git checkout $FFMPEG_KIT_CHECKOUT

# CMake 4.x (Homebrew): x265 vendored CMakeLists used OLD policies CMP0025/CMP0054 (unsupported)
# and had project() before cmake_minimum_required(). See patches/ffmpeg-kit-x265-cmake.patch.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
X265_CMAKE_PATCH="${SCRIPT_DIR}/patches/ffmpeg-kit-x265-cmake.patch"
if [ -f "${X265_CMAKE_PATCH}" ] && [ -f tools/patch/cmake/x265/CMakeLists.txt ]; then
  if grep -q 'cmake_policy(SET CMP0025 OLD)' tools/patch/cmake/x265/CMakeLists.txt; then
    echo "Applying x265 CMake patch for CMake 4.x..."
    patch -p1 --fuzz=0 < "${X265_CMAKE_PATCH}" || exit 1
  fi
fi

echo "Install build dependencies..."
brew install autoconf automake libtool pkg-config curl git doxygen nasm cmake gcc gperf texinfo yasm bison autogen wget gettext meson ninja ragel groff gtk-doc docbook docbook-xsl libtasn1 gh --overwrite

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

echo "Building for iOS..."
./ios.sh -x --full --enable-gpl --disable-lib-srt --disable-lib-gnutls --disable-lib-lame
echo "Building for tvOS..."
./tvos.sh -x --full --enable-gpl --disable-lib-srt --disable-lib-gnutls --disable-lib-lame
echo "Building for macOS..."
./macos.sh -x --full --enable-gpl --disable-lib-srt --disable-lib-gnutls --disable-lib-lame
echo "Building for watchOS..."
#./watchos.sh --enable-watchos-zlib --enable-watchos-bzip2 --no-bitcode --enable-gmp --enable-gnutls -x

echo "Bundling final XCFramework"
./apple.sh --disable-watchos --disable-watchsimulator

cd ../../

echo "Updating package file..."
PACKAGE_STRING=""
sed -i '' -e "s/let release =.*/let release = \"$FFMPEG_KIT_TAG\"/" Package.swift

XCFRAMEWORK_DIR="$WORK_DIR/prebuilt/bundle-apple-xcframework"

rm -rf $XCFRAMEWORK_DIR/*.zip

for f in $(ls "$XCFRAMEWORK_DIR")
do
    echo "Adding $f to package list..."
    PACAKGE="$XCFRAMEWORK_DIR/$f"
    ditto -c -k --sequesterRsrc --keepParent $PACAKGE "$PACAKGE.zip"
    PACKAGE_NAME=$(basename "$f" .xcframework)
    PACKAGE_SUM=$(sha256sum "$PACAKGE.zip" | awk '{ print $1 }')
    PACKAGE_STRING="$PACKAGE_STRING\"$PACKAGE_NAME\": \"$PACKAGE_SUM\", "
done

PACKAGE_STRING=$(basename "$PACKAGE_STRING" ", ")
sed -i '' -e "s/let frameworks =.*/let frameworks = [$PACKAGE_STRING]/" Package.swift

echo "Copying License..."
cp -f .tmp/ffmpeg-kit/LICENSE ./

echo "Committing Changes..."
git add -u
git commit -m "Creating release for $FFMPEG_KIT_TAG"

echo "Creating Tag..."
git tag $FFMPEG_KIT_TAG
git push
git push origin --tags

echo "Creating Release..."
gh release create -p -d $FFMPEG_KIT_TAG -t "FFmpegKit SPM $FFMPEG_KIT_TAG" --generate-notes --verify-tag

echo "Uploading Binaries..."
for f in $(ls "$XCFRAMEWORK_DIR")
do
    if [[ $f == *.zip ]]; then
        gh release upload $FFMPEG_KIT_TAG "$XCFRAMEWORK_DIR/$f"
    fi
done

gh release edit $FFMPEG_KIT_TAG --draft=false

echo "All done!"
