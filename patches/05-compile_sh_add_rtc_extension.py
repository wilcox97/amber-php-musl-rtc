#!/usr/bin/env python3
"""
Patch 5/5: wire ext-rtc into PHP-Binaries' own compile.sh pipeline, the
same way its other third-party static extensions (snappy, crypto, ...)
are integrated: copy the (already-patched) ext-rtc sources into the PHP
source tree being built, and add --enable-rtc --with-libdatachannel=...
to the main ./configure invocation.
Env: EXT_RTC_SRC, STATIC_INSTALL (the static libdatachannel install
prefix from step 02), and PHP_BINARIES_SRC must all be set.
"""
import os

ext_rtc_src = os.environ["EXT_RTC_SRC"]
static_install = os.environ["STATIC_INSTALL"]
compile_sh = os.path.join(os.environ["PHP_BINARIES_SRC"], "compile.sh")
src = open(compile_sh).read()

old_copy_anchor = '''cd "$BUILD_DIR/php"
write_done

get_github_extension "snappy" "$EXT_SNAPPY_VERSION" "kjdev" "php-ext-snappy"
'''
new_copy_block = '''cd "$BUILD_DIR/php"
write_done

echo -n "  rtc: copying pinned ext-rtc sources..."
rm -rf "$BUILD_DIR/php/ext/rtc"
mkdir -p "$BUILD_DIR/php/ext/rtc"
cp -r "{ext_rtc_src}/config.m4" "{ext_rtc_src}/config.w32" "{ext_rtc_src}/php_rtc.h" "{ext_rtc_src}/src" "{ext_rtc_src}/stubs" "$BUILD_DIR/php/ext/rtc/" >> "$DIR/install.log" 2>&1
write_done

get_github_extension "snappy" "$EXT_SNAPPY_VERSION" "kjdev" "php-ext-snappy"
'''.format(ext_rtc_src=ext_rtc_src)

assert src.count(old_copy_anchor) == 1, "compile.sh snappy anchor not found (upstream changed this section)"
src = src.replace(old_copy_anchor, new_copy_block)

old_configure_anchor = '''--enable-igbinary \\
--with-crypto \\
--enable-recursionguard \\
'''
new_configure_block = '''--enable-igbinary \\
--with-crypto \\
--enable-rtc \\
--with-libdatachannel="{static_install}" \\
--enable-recursionguard \\
'''.format(static_install=static_install)

assert src.count(old_configure_anchor) == 1, "compile.sh configure anchor not found (upstream changed this section)"
src = src.replace(old_configure_anchor, new_configure_block)

open(compile_sh, "w").write(src)
print("patch 05 applied")
