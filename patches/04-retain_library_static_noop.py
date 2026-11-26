#!/usr/bin/env python3
"""
Patch 4/5: make retain_library() a no-op for static builds.

ext-rtc's retain_library() (src/peer/peer.cpp) calls dladdr()+dlopen()
on its own containing .so to "pin" it against being unloaded out from
under a background thread. musl does not support dlopen() from a static
binary at all, so this throws (amber::rtc::Error: "Unable to retain RTC
library lifetime") the moment a PeerConnection is created, crashing the
whole process via std::terminate (an uncaught native exception, not a
catchable PHP exception). When ext-rtc is linked directly into the main
php executable there is nothing to pin: the code is resident in the
executable's own text segment for the entire process lifetime. The
original dlopen()-based logic is kept, but gated behind a macro
(AMBER_RTC_SHARED_MODULE) that this build never defines, in case this
patch is ever reused for a genuine shared-module build.
Env: EXT_RTC_SRC must point at the ext-rtc checkout.
"""
import os

peer_cpp = os.path.join(os.environ["EXT_RTC_SRC"], "src", "peer", "peer.cpp")
src = open(peer_cpp).read()

old = '''void retain_library(const void* address){
	// moved closed callbacks can outlive resetCallbacks
#ifdef _WIN32
	HMODULE module;
	if(!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
						   reinterpret_cast<LPCWSTR>(address), &module)){
		throw Error(11, "Unable to retain RTC library lifetime");
	}
#else
	Dl_info info{};
	if(!dladdr(address, &info) || !dlopen(info.dli_fname, RTLD_NOW | RTLD_NODELETE)){
		throw Error(11, "Unable to retain RTC library lifetime");
	}
#endif
}'''
new = '''void retain_library(const void* address){
    // moved closed callbacks can outlive resetCallbacks.
    // When ext-rtc and libdatachannel are statically linked into the main
    // executable (our build: musl does not support dlopen() from static
    // binaries at all, so the extension can never be a loadable .so here),
    // the "library" is the executable's own text segment, which is resident
    // for the whole process lifetime. There is nothing to pin, and dlopen()
    // on the running executable would fail (or be unsupported) regardless,
    // so this is a safe no-op in that configuration.
    (void)address;
#ifdef AMBER_RTC_SHARED_MODULE
#ifdef _WIN32
    HMODULE module;
    if(!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
                           reinterpret_cast<LPCWSTR>(address), &module)){
        throw Error(11, "Unable to retain RTC library lifetime");
    }
#else
    Dl_info info{};
    if(!dladdr(address, &info) || !dlopen(info.dli_fname, RTLD_NOW | RTLD_NODELETE)){
        throw Error(11, "Unable to retain RTC library lifetime");
    }
#endif
#endif
}'''
assert src.count(old) == 1, "retain_library() not found (already patched, or upstream changed this function)"
src = src.replace(old, new)

open(peer_cpp, "w").write(src)
print("patch 04 applied")
