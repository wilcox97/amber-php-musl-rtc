#!/usr/bin/env bash
# Builds libdatachannel (+ its bundled libjuice/usrsctp deps) as static
# .a archives for aarch64-musl, linked against the static OpenSSL from
# step 01. This is the core of the static-link approach: the stock
# ext-rtc build-linux.sh only ever builds these as shared libraries.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/env.sh

ssl_prefix="$(PKG_CONFIG_PATH="$EXT_RTC_SRC/.build/openssl/lib/pkgconfig" pkg-config --variable=prefix openssl)"
source_dir="$EXT_RTC_SRC/.build/rtc/libdatachannel"
static_build="$EXT_RTC_SRC/.build/rtc-static"

rm -rf "$static_build"
mkdir -p "$static_build"

patched_source="$static_build/backend-source"
cmake -DROOT="$EXT_RTC_SRC" -DSOURCE="$source_dir" -DDESTINATION="$patched_source" \
  -P "$EXT_RTC_SRC/build/patches/prepare-backend.cmake"

cmake -S "$patched_source" -B "$static_build/backend" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$STATIC_INSTALL" -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
  -DCMAKE_C_COMPILER=aarch64-linux-musl-gcc -DCMAKE_CXX_COMPILER=aarch64-linux-musl-g++ \
  -DCMAKE_C_FLAGS=-DICE_MAX_CANDIDATES_COUNT=64 \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DOPENSSL_ROOT_DIR="$ssl_prefix" -DOPENSSL_USE_STATIC_LIBS=ON \
  -DBUILD_SHARED_LIBS=OFF -DBUILD_SHARED_DEPS_LIBS=OFF \
  -DNO_MEDIA=ON -DNO_WEBSOCKET=ON -DNO_EXAMPLES=ON -DNO_TESTS=ON \
  -DUSE_GNUTLS=OFF -DUSE_MBEDTLS=OFF -DUSE_NICE=OFF \
  -DUSE_SYSTEM_JUICE=OFF -DUSE_SYSTEM_USRSCTP=OFF -DUSE_SYSTEM_PLOG=OFF

cmake --build "$static_build/backend" --parallel "$(nproc)"
cmake --install "$static_build/backend"

find "$STATIC_INSTALL/lib" -maxdepth 1 -name "*.a"
echo "STATIC_LIBDATACHANNEL_READY: $STATIC_INSTALL"
