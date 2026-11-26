#!/usr/bin/env bash
# Runs Amber-PM's own compile.sh cross-compile pipeline for android-aarch64
# (musl libc, despite the name -- that's PHP-Binaries' own target string for
# this architecture), which now builds PHP 8.4.27 with ext-rtc compiled in
# statically, thanks to the patches applied in step 03.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/env.sh

cd "$PHP_BINARIES_SRC"
rm -rf install_data/subdir
mkdir -p "$BUILD_ROOT/download_cache" "$BUILD_ROOT/lib-cache"

bash compile.sh -x -t android-aarch64 -P5 -z 8.4 \
  -j "$(nproc)" \
  -c "$BUILD_ROOT/download_cache" -l "$BUILD_ROOT/lib-cache"

bin="$PHP_BINARIES_SRC/bin-sdx72/php7/bin/php"
[ -x "$bin" ] || bin="$(find "$PHP_BINARIES_SRC" -maxdepth 3 -type f -name php -path '*/bin/*' -print -quit)"
test -x "$bin"
echo "PHP_BUILD_READY: $bin"
