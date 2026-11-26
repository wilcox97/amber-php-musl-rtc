#!/usr/bin/env bash
# Packages the cross-compiled php binary as an OpenWrt .ipk. The real ipk
# container format is a gzip-compressed outer tar (NOT ar-based, unlike
# Debian's .deb, and NOT a plain uncompressed tar either) -- confirmed by
# pulling a genuine reference package from a real router's own opkg feed
# and inspecting it with `file`/`tar -tvf`.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/env.sh

PHP_BIN="${1:?usage: 05-package-ipk.sh /path/to/cross-compiled/php}"
VERSION="$(lock_get php_version)-1"
ARCH="$(python3 -c "import json;print(json.load(open('VERSIONS.lock'))['target']['arch'])")"
PKG_NAME="amber-php8-rtc"
OUT_DIR="$BUILD_ROOT/output"
STAGE="$BUILD_ROOT/ipk-stage"

rm -rf "$STAGE"
mkdir -p "$STAGE/opt/amber-php/bin" "$STAGE/opt/amber-php/etc" "$OUT_DIR"

aarch64-linux-musl-strip -o "$STAGE/opt/amber-php/bin/php" "$PHP_BIN"

cat > "$STAGE/opt/amber-php/etc/php.ini" <<'INI'
memory_limit = 512M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_NOTICE
display_errors = Off
log_errors = On
error_log = /opt/amber-php/var/php_errors.log
date.timezone = UTC
openssl.cafile = /etc/ssl/certs/ca-certificates.crt
pcre.jit = 0
INI

mkdir -p "$STAGE/control"
cat > "$STAGE/control/control" <<CTL
Package: $PKG_NAME
Version: $VERSION
Architecture: $ARCH
Depends: libc
Source: https://github.com/wilcox97/amber-php-musl-rtc
Description: Statically-linked aarch64-musl PHP 8.4 with ext-rtc (NetherNet/WebRTC) built in, for running Amber-PM alongside an existing PocketMine-MP install.
CTL
cat > "$STAGE/control/postinst" <<'PI'
#!/bin/sh
chmod 755 /opt/amber-php/bin/php
mkdir -p /opt/amber-php/var
exit 0
PI
chmod 755 "$STAGE/control/postinst"

IPK_WORK="$BUILD_ROOT/ipk-work"
rm -rf "$IPK_WORK"
mkdir -p "$IPK_WORK"
echo "2.0" > "$IPK_WORK/debian-binary"
tar --numeric-owner --owner=0 --group=0 -C "$STAGE/control" -czf "$IPK_WORK/control.tar.gz" ./control ./postinst
tar --numeric-owner --owner=0 --group=0 -C "$STAGE" -czf "$IPK_WORK/data.tar.gz" ./opt

IPK_PATH="$OUT_DIR/${PKG_NAME}_${VERSION}_${ARCH}.ipk"
tar --numeric-owner --owner=0 --group=0 -C "$IPK_WORK" -czf "$IPK_PATH" ./debian-binary ./control.tar.gz ./data.tar.gz

echo "IPK_READY: $IPK_PATH"
