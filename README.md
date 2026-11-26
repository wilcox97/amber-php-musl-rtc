# amber-php-musl-rtc

A **statically-linked, aarch64-musl cross-build of PHP 8.4** with
[Amber-PM's `ext-rtc`](https://github.com/Amber-PM/ext-rtc) (the NetherNet /
WebRTC transport extension that lets [Amber](https://github.com/Amber-PM/Amber),
a PocketMine-MP fork, speak to modern Minecraft Bedrock clients) compiled
directly **into** the PHP binary, packaged as an installable OpenWrt `.ipk`.

Built and verified running on a real **GL.iNet Mudi 7 (GL-E5800)** router
(OpenWrt 23.05.4, `sdx72/generic`, `aarch64_cortex-a53`), installed to
`/opt/amber-php/` **alongside** an existing PHP/PocketMine-MP install —
nothing in an existing setup is touched or replaced.

## Why this exists

`ext-rtc` is normally built as a loadable `.so` extension (`phpize`-style).
That doesn't work on OpenWrt/musl targets, because **musl's static-binary
toolchain path does not support `dlopen()` at all** — not "supports it
badly," not "needs a flag," genuinely absent. Two separate things break
because of this:

1. **Loading** `rtc.so` as a PHP extension — a static PHP binary can't
   `dlopen()` anything, including its own extensions, on this target.
2. **`ext-rtc`'s own internal self-pinning.** Even once you get past (1),
   `ext-rtc`'s `retain_library()` (in `src/peer/peer.cpp`) calls
   `dladdr()` + `dlopen(RTLD_NODELETE)` on itself at runtime, as a safety
   mechanism to stop its `.so` from being unloaded out from under a
   background thread. On a static binary there is no `.so` to re-open, so
   this throws and crashes the process (`std::terminate`) the moment a
   `PeerConnection` is created.

The fix used here is to stop building `ext-rtc` as a module at all, and
instead **compile and statically link it directly into the `php` binary**
(the same way PHP's own built-in extensions work), which sidesteps both
problems — there's no `.so` to load or to pin, because the code is already
permanently resident in the executable.

## What's in this repo

- **`patches/`** — five small, targeted patches (Python find/replace
  scripts, applied against a specific pinned `ext-rtc` commit) that make
  static linking actually work. See each file's docstring for exactly
  what it changes and why:
  - `01-config_m4_static_lib_detect.py` — detect a static `libdatachannel.a`
    (not just the `.so` the stock `config.m4` expects).
  - `02-config_m4_link_order_fix.py` — the important one. PHP's
    `PHP_ADD_LIBRARY(lib, 1, SOME_VARNAME)` only honors the third
    ("extra-libadd") argument for **shared**-module builds; for static
    builds it's silently ignored, so the original `config.m4`'s
    `RTC_SHARED_LIBADD` variable was never actually read by the final
    link step — the archives were being built but never linked in,
    which surfaced as dozens of `undefined reference to rtc::*` errors.
    Fixed by linking via plain `-l<name>` through PHP's global static
    accumulator instead.
  - `03-php_rtc_h_extern_c_guard.py` — PHP's build auto-generates a
    plain-C file that `#include`s every extension's header to declare its
    module pointer. `php_rtc.h`'s unguarded `extern "C" { ... }` and
    `static_assert` broke under a C (not C++) compiler once the header
    was reachable from outside its own `.cpp` files for the first time.
  - `04-retain_library_static_noop.py` — makes the self-pinning
    `dlopen()` call in `retain_library()` a no-op, gated behind a macro
    that's never defined in this build. Nothing needs pinning when the
    code is already part of the main executable for the life of the
    process.
  - `05-compile_sh_add_rtc_extension.py` — wires `ext-rtc` into
    Amber-PM's `PHP-Binaries/compile.sh` build pipeline (source copy +
    `--enable-rtc --with-libdatachannel=...` configure flags), the same
    way its other third-party static extensions are integrated.

- **`scripts/`** — the full build pipeline, broken into numbered,
  individually re-runnable steps (toolchain setup, static OpenSSL for
  libdatachannel, static libdatachannel itself, applying the patches
  above, the actual PHP cross-compile, and `.ipk` packaging), plus an
  optional SSH deploy script and a standalone functional smoke test.

- **`build.sh`** — orchestrates all of the numbered scripts in order.

- **`.github/workflows/build.yml`** — watches Amber-PM's upstream
  `ext-rtc` and `PHP-Binaries` repos for new commits and automatically
  re-runs the whole pipeline, publishing a fresh `.ipk` as a GitHub
  Release when something changed.

## Building it yourself

```
git clone https://github.com/wilcox97/amber-php-musl-rtc.git
cd amber-php-musl-rtc
./build.sh
```

Needs a Linux x86_64 host with the usual autoconf/cmake/ninja/bison/re2c
toolchain packages (see `.github/workflows/build.yml` for the exact
package list used in CI). `build.sh` downloads the
[`aarch64-linux-musl-cross`](https://musl.cc/) toolchain itself if it
isn't already on `PATH`. A full clean build (OpenSSL x2, libdatachannel,
grpc, and PHP itself) takes roughly 45–90 minutes depending on the
machine; output lands in `build/output/amber-php8-rtc_<version>_aarch64_cortex-a53.ipk`.

## Installing on a router

```
opkg install amber-php8-rtc_*.ipk
/opt/amber-php/bin/php -v
/opt/amber-php/bin/php --ri rtc
```

Installs entirely under `/opt/amber-php/` — it will not touch or
conflict with an existing PHP/PocketMine-MP install in another prefix.

## Status

The PHP binary + `ext-rtc` extension have been verified **on real Mudi 7
router hardware** (not just emulation): `php --ri rtc` reports the
extension loaded with the correct `libdatachannel` identity, and a
standalone smoke test (`scripts/smoke-test.php`) successfully creates a
`PeerConnection`, generates a local SDP offer, and gathers real ICE
candidates against a public STUN server. Running a full Amber-PM server
instance end-to-end with this build (i.e. an actual Bedrock client
connecting over NetherNet) hasn't been tested yet — that's the next
milestone.

## License

The scripts and patches in this repo are MIT-licensed. They build (and
this repo does not redistribute) PHP (PHP License), `ext-rtc` (MIT),
and `libdatachannel` and its dependencies (MPL-2.0 / BSD-3-Clause) —
see each upstream project for its own license.
