#define _GNU_SOURCE
#include <X11/Xlib.h>
#include <dlfcn.h>
#include <stdint.h>
#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

/*
 * AweSun 16.6.0.32198 passes false for both text directions when creating a
 * controller session on the tested Manjaro host.  These two native FFI entry
 * points configure the session independently from the UI's master clipboard
 * switch.  The user explicitly opts in to fixing the two text directions by
 * setting SUNLOGIN_FUSIONFIX_CLIPBOARD_TEXT=1 in the launcher.
 *
 * File transfer arguments are passed through unchanged.  The vendor's master
 * clipboard switch and remote-side permission checks remain in its code.
 */

typedef void *(*dlsym_fn)(void *, const char *);
typedef int (*sync_fn)(uint32_t, int, int);

static dlsym_fn libc_dlsym(void) {
    static _Atomic(dlsym_fn) fn;
    dlsym_fn cached = atomic_load_explicit(&fn, memory_order_acquire);
    if (cached) return cached;
    cached = (dlsym_fn)dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.34");
    if (!cached) cached = (dlsym_fn)dlvsym(RTLD_NEXT, "dlsym", "GLIBC_2.2.5");
    atomic_store_explicit(&fn, cached, memory_order_release);
    return cached;
}

static int text_opted_in(void) {
    const char *value = getenv("SUNLOGIN_FUSIONFIX_CLIPBOARD_TEXT");
    return value && strcmp(value, "1") == 0;
}

static _Atomic(sync_fn) original_to;
static _Atomic(sync_fn) original_from;

int control_desktop_sync_clipboard_to_remote(uint32_t id, int text, int files) {
    sync_fn fn = atomic_load_explicit(&original_to, memory_order_acquire);
    if (!fn) {
        dlsym_fn lookup = libc_dlsym();
        if (lookup) fn = (sync_fn)lookup(RTLD_NEXT, "control_desktop_sync_clipboard_to_remote");
    }
    if (!fn) return -1;
    return fn(id, text_opted_in() ? 1 : text, files);
}

int control_desktop_sync_clipboard_from_remote(uint32_t id, int text, int files) {
    sync_fn fn = atomic_load_explicit(&original_from, memory_order_acquire);
    if (!fn) {
        dlsym_fn lookup = libc_dlsym();
        if (lookup) fn = (sync_fn)lookup(RTLD_NEXT, "control_desktop_sync_clipboard_from_remote");
    }
    if (!fn) return -1;
    return fn(id, text_opted_in() ? 1 : text, files);
}

void *dlsym(void *handle, const char *symbol) {
    dlsym_fn lookup = libc_dlsym();
    if (!lookup) return NULL;
    void *original = lookup(handle, symbol);
    if (!original || !text_opted_in()) return original;
    if (strcmp(symbol, "control_desktop_sync_clipboard_to_remote") == 0) {
        atomic_store_explicit(&original_to, (sync_fn)original, memory_order_release);
        return (void *)&control_desktop_sync_clipboard_to_remote;
    }
    if (strcmp(symbol, "control_desktop_sync_clipboard_from_remote") == 0) {
        atomic_store_explicit(&original_from, (sync_fn)original, memory_order_release);
        return (void *)&control_desktop_sync_clipboard_from_remote;
    }
    return original;
}

Display *XOpenDisplay(const char *name) {
    dlsym_fn lookup = libc_dlsym();
    Display *(*open_display)(const char *) = lookup ? lookup(RTLD_NEXT, "XOpenDisplay") : NULL;
    if (!open_display) return NULL;

    const char *active = getenv("DISPLAY");
    if (name && strcmp(name, ":0") == 0 && active && strcmp(active, ":0") != 0)
        return open_display(active);
    return open_display(name);
}
