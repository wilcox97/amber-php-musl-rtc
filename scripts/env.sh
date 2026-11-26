# Shared environment for all numbered build scripts. Source, don't execute.
: "${BUILD_ROOT:=$HOME/amber-rtc-build}"
: "${TOOLCHAIN_DIR:=$BUILD_ROOT/aarch64-linux-musl-cross}"
: "${PHP_BINARIES_REPO:=https://github.com/Amber-PM/PHP-Binaries.git}"
: "${EXT_RTC_REPO:=https://github.com/Amber-PM/ext-rtc.git}"

LOCKFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/VERSIONS.lock"
lock_get() { python3 -c "import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$LOCKFILE" "$1"; }

: "${EXT_RTC_COMMIT:=$(lock_get ext_rtc_commit)}"
: "${PHP_BINARIES_COMMIT:=$(lock_get php_binaries_commit)}"

export PATH="$BUILD_ROOT/cross-shim:$TOOLCHAIN_DIR/bin:$PATH"
export CROSS_BIN="$TOOLCHAIN_DIR/bin"
export QEMU_LD_PREFIX="$TOOLCHAIN_DIR/aarch64-linux-musl"

EXT_RTC_SRC="$BUILD_ROOT/ext-rtc"
PHP_BINARIES_SRC="$BUILD_ROOT/PHP-Binaries"
STATIC_INSTALL="$EXT_RTC_SRC/.build/rtc-static/install"
mkdir -p "$BUILD_ROOT"
