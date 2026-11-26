#!/usr/bin/env python3
"""
Patch 3/5: guard php_rtc.h's extern "C" block and static_assert behind
#ifdef __cplusplus. PHP's build auto-generates main/internal_functions_cli.c
(compiled as plain C), which #includes every registered extension's main
header to declare its phpext_<name>_ptr symbol. That broke here because
php_rtc.h's extern "C" / static_assert were never previously reachable
from outside the extension's own .cpp files (compiled as C++) -- this
only surfaces once ext-rtc is built directly into PHP's source tree
instead of as a standalone phpize module.
Env: EXT_RTC_SRC must point at the ext-rtc checkout.
"""
import os

header = os.path.join(os.environ["EXT_RTC_SRC"], "php_rtc.h")
src = open(header).read()

old = '''#ifndef PHP_RTC_H
#define PHP_RTC_H

extern "C" {
#include "php.h"
}

#if PHP_VERSION_ID < 80100
#error "ext-rtc requires PHP 8.1 or newer"
#endif
static_assert(sizeof(zend_long) == 8, "ext-rtc initial builds require a 64-bit PHP ABI");
'''
new = '''#ifndef PHP_RTC_H
#define PHP_RTC_H

#ifdef __cplusplus
extern "C" {
#endif
#include "php.h"
#ifdef __cplusplus
}
#endif

#if PHP_VERSION_ID < 80100
#error "ext-rtc requires PHP 8.1 or newer"
#endif
#ifdef __cplusplus
static_assert(sizeof(zend_long) == 8, "ext-rtc initial builds require a 64-bit PHP ABI");
#endif
'''
assert src.count(old) == 1, "php_rtc.h header block not found (already patched, or upstream changed this section)"
src = src.replace(old, new)

open(header, "w").write(src)
print("patch 03 applied")
