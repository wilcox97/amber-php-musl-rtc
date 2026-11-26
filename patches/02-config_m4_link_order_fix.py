#!/usr/bin/env python3
"""
Patch 2/5: fix static linking of libdatachannel into PHP.

PHP_ADD_LIBRARY(name, shared_only, [extra_libadd_varname]) only appends to
the *named* extra-libadd variable when $ext_shared = yes. For static
builds it falls through to PHP_ADD_LIBRARY_DEFER, which appends to PHP's
own global static-link accumulator instead -- completely ignoring any
named variable. The original config.m4 built RTC_SHARED_LIBADD by hand and
that variable is never read for a static build, so libdatachannel's
archives were built but never actually linked into the php binary
(-> "undefined reference to rtc::*"). Fix: link by name through the global
accumulator instead of through RTC_SHARED_LIBADD.

Must run after patch 01. Env: EXT_RTC_SRC must point at the ext-rtc checkout.
"""
import os

config_m4 = os.path.join(os.environ["EXT_RTC_SRC"], "config.m4")
src = open(config_m4).read()

old = '''  PHP_ADD_INCLUDE([$PHP_LIBDATACHANNEL/include])
  PHP_ADD_LIBPATH([$PHP_LIBDATACHANNEL/lib], [RTC_SHARED_LIBADD])
  RTC_SHARED_LIBADD="$RTC_SHARED_LIBADD -Wl,$PHP_LIBDATACHANNEL/lib/libdatachannel.so"
  PHP_ADD_LIBRARY([stdc++], [1], [RTC_SHARED_LIBADD])
  PHP_ADD_LIBRARY([dl], [1], [RTC_SHARED_LIBADD])
  PHP_SUBST([RTC_SHARED_LIBADD])
'''
new = '''  PHP_ADD_INCLUDE([$PHP_LIBDATACHANNEL/include])
  PHP_ADD_LIBPATH([$PHP_LIBDATACHANNEL/lib])
  PHP_ADD_LIBRARY([datachannel], [1])
  if test -f "$PHP_LIBDATACHANNEL/lib/libjuice.a"; then
    PHP_ADD_LIBRARY([juice], [1])
  fi
  if test -f "$PHP_LIBDATACHANNEL/lib/libusrsctp.a"; then
    PHP_ADD_LIBRARY([usrsctp], [1])
  fi
  PHP_ADD_LIBRARY([stdc++], [1])
'''
assert src.count(old) == 1, "config.m4 link block not found (already patched, or upstream changed this section)"
src = src.replace(old, new)

open(config_m4, "w").write(src)
print("patch 02 applied")
