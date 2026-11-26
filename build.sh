#!/usr/bin/env bash
# Orchestrates the full pipeline: toolchain -> static OpenSSL for rtc ->
# static libdatachannel -> apply patches -> cross-compile PHP -> package
# the .ipk. Each step is individually re-runnable (see scripts/NN-*.sh);
# this just runs them in order. Override BUILD_ROOT to change where
# sources/build artifacts land (default: ~/amber-rtc-build).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source scripts/env.sh

echo "== step 00: toolchain =="
bash scripts/00-setup-toolchain.sh

echo "== step 01: static OpenSSL for libdatachannel =="
bash scripts/01-build-openssl-for-rtc.sh

echo "== step 02: static libdatachannel =="
bash scripts/02-build-static-libdatachannel.sh

echo "== step 03: apply patches =="
bash scripts/03-apply-patches.sh

echo "== step 04: cross-compile PHP =="
bash scripts/04-build-php.sh > "$BUILD_ROOT/php_build.log" 2>&1 &
build_pid=$!
echo "PHP build running in background (pid $build_pid), log: $BUILD_ROOT/php_build.log"
wait "$build_pid"
php_bin="$(tail -5 "$BUILD_ROOT/php_build.log" | grep -oP '(?<=PHP_BUILD_READY: ).*')"
test -n "$php_bin"

echo "== step 05: package .ipk =="
bash scripts/05-package-ipk.sh "$php_bin"

echo "BUILD_COMPLETE"
