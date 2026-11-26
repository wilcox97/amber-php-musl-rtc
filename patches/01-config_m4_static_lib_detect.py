#!/usr/bin/env python3
"""
Patch 1/5: teach ext-rtc's config.m4 to detect a *static* libdatachannel.a
(plus its static libjuice.a/libusrsctp.a deps), not just the .so the stock
config.m4 hardcodes. Run after ext-rtc is checked out, before patch 02.
Env: EXT_RTC_SRC must point at the ext-rtc checkout.
"""
import os

config_m4 = os.path.join(os.environ["EXT_RTC_SRC"], "config.m4")
src = open(config_m4).read()

old = '''  if test "$PHP_LIBDATACHANNEL" = "no" || test ! -f "$PHP_LIBDATACHANNEL/include/rtc/global.hpp"; then
    AC_MSG_ERROR([rtc requires --with-libdatachannel=PREFIX containing pinned headers])
  fi
  if test ! -f "$PHP_LIBDATACHANNEL/lib/libdatachannel.so"; then
    AC_MSG_ERROR([rtc requires linkable libdatachannel 0.24.6 with its message-lifetime overload and identity symbol in PREFIX/lib])
  fi
'''
new = '''  if test "$PHP_LIBDATACHANNEL" = "no" || test ! -f "$PHP_LIBDATACHANNEL/include/rtc/global.hpp"; then
    AC_MSG_ERROR([rtc requires --with-libdatachannel=PREFIX containing pinned headers])
  fi
  rtc_dc_lib=""
  if test -f "$PHP_LIBDATACHANNEL/lib/libdatachannel.a"; then
    rtc_dc_lib="$PHP_LIBDATACHANNEL/lib/libdatachannel.a"
  elif test -f "$PHP_LIBDATACHANNEL/lib/libdatachannel.so"; then
    rtc_dc_lib="$PHP_LIBDATACHANNEL/lib/libdatachannel.so"
  else
    AC_MSG_ERROR([rtc requires linkable libdatachannel 0.24.6 with its message-lifetime overload and identity symbol in PREFIX/lib])
  fi
  rtc_extra_static_libs=""
  for rtc_sl in libjuice.a libusrsctp.a; do
    if test -f "$PHP_LIBDATACHANNEL/lib/$rtc_sl"; then
      rtc_extra_static_libs="$rtc_extra_static_libs $PHP_LIBDATACHANNEL/lib/$rtc_sl"
    fi
  done
'''
assert src.count(old) == 1, "config.m4 detection block not found (already patched, or upstream changed this section)"
src = src.replace(old, new)

old_libs_line = 'LIBS="$PHP_LIBDATACHANNEL/lib/libdatachannel.so $LIBS"'
new_libs_line = 'LIBS="$rtc_dc_lib $rtc_extra_static_libs $LIBS"'
if old_libs_line in src:
    src = src.replace(old_libs_line, new_libs_line)

open(config_m4, "w").write(src)
print("patch 01 applied")
