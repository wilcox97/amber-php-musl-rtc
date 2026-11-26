#!/usr/bin/env bash
# Downloads the aarch64-linux-musl-cross toolchain (from musl.cc) if it
# isn't already present at $TOOLCHAIN_DIR, and sets up a small "cross-shim"
# directory with the plain cc/c++/ld/ar/ranlib/strip names some build
# systems (OpenSSL's Configure, in particular) expect to find on PATH.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/env.sh

if [ ! -x "$TOOLCHAIN_DIR/bin/aarch64-linux-musl-gcc" ]; then
  echo "Downloading aarch64-linux-musl-cross toolchain..."
  mkdir -p "$BUILD_ROOT"
  curl -fsSL -o "$BUILD_ROOT/toolchain.tgz" https://musl.cc/aarch64-linux-musl-cross.tgz
  tar -xzf "$BUILD_ROOT/toolchain.tgz" -C "$BUILD_ROOT"
  rm -f "$BUILD_ROOT/toolchain.tgz"
fi

mkdir -p "$BUILD_ROOT/cross-shim"
for pair in cc:gcc gcc:gcc c++:g++ g++:g++ ld:ld ar:ar ranlib:ranlib strip:strip; do
  shim_name="${pair%%:*}"; real_suffix="${pair##*:}"
  ln -sf "$CROSS_BIN/aarch64-linux-musl-$real_suffix" "$BUILD_ROOT/cross-shim/$shim_name"
done

echo "TOOLCHAIN_READY: $TOOLCHAIN_DIR"
