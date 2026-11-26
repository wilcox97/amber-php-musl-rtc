#!/usr/bin/env bash
# Clones PHP-Binaries at the pinned commit, then applies the five patches
# in patches/ (in order) against the ext-rtc checkout from step 01 and
# this fresh PHP-Binaries checkout.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/env.sh

if [ ! -d "$PHP_BINARIES_SRC/.git" ]; then
  git clone -q "$PHP_BINARIES_REPO" "$PHP_BINARIES_SRC"
fi
git -C "$PHP_BINARIES_SRC" fetch -q origin "$PHP_BINARIES_COMMIT" || true
git -C "$PHP_BINARIES_SRC" checkout -q --detach "$PHP_BINARIES_COMMIT"
test "$(git -C "$PHP_BINARIES_SRC" rev-parse HEAD)" = "$PHP_BINARIES_COMMIT"

for p in patches/0{1,2,3,4}-*.py; do
  echo "applying $p ..."
  EXT_RTC_SRC="$EXT_RTC_SRC" python3 "$p"
done

echo "applying patches/05-compile_sh_add_rtc_extension.py ..."
EXT_RTC_SRC="$EXT_RTC_SRC" STATIC_INSTALL="$STATIC_INSTALL" PHP_BINARIES_SRC="$PHP_BINARIES_SRC" \
  python3 patches/05-compile_sh_add_rtc_extension.py

echo "PATCHES_APPLIED"
