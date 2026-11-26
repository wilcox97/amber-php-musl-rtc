#!/usr/bin/env bash
# Clones ext-rtc at the pinned commit (if not already present) and builds
# its own static OpenSSL copy (used only as the TLS backend for the static
# libdatachannel build in step 02 — PHP's own main build gets a separate
# OpenSSL via compile.sh in step 05). ext-rtc ships scripts/build-openssl.sh
# for this, written for same-arch/native builds; we patch it in place to
# cross-compile for linux-aarch64 instead.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/env.sh
export CC=aarch64-linux-musl-gcc CXX=aarch64-linux-musl-g++
export AR=aarch64-linux-musl-ar RANLIB=aarch64-linux-musl-ranlib STRIP=aarch64-linux-musl-strip
export CFLAGS="-march=armv8-a -mtune=generic -fPIC"
export CXXFLAGS="-march=armv8-a -mtune=generic -fPIC"

if [ ! -d "$EXT_RTC_SRC/.git" ]; then
  git clone -q "$EXT_RTC_REPO" "$EXT_RTC_SRC"
fi
git -C "$EXT_RTC_SRC" fetch -q origin "$EXT_RTC_COMMIT" || true
git -C "$EXT_RTC_SRC" checkout -q --detach "$EXT_RTC_COMMIT"
test "$(git -C "$EXT_RTC_SRC" rev-parse HEAD)" = "$EXT_RTC_COMMIT"

if [ ! -d "$EXT_RTC_SRC/.build/openssl" ]; then
  sed -i 's|^\./Configure "--prefix=\$prefix" "--libdir=lib" shared no-tests$|./Configure linux-aarch64 "--prefix=$prefix" "--libdir=lib" shared no-tests|' \
    "$EXT_RTC_SRC/scripts/build-openssl.sh"
  grep -q 'Configure linux-aarch64' "$EXT_RTC_SRC/scripts/build-openssl.sh" || { echo "PATCH_FAILED_OPENSSL" >&2; exit 1; }
  bash "$EXT_RTC_SRC/scripts/build-openssl.sh"
fi

echo "OPENSSL_FOR_RTC_READY: $EXT_RTC_SRC/.build/openssl"
