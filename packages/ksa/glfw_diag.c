/*
 * GLFW wrapper shim for KSA on Wayland.
 * Replaces libglfw.so — forwards to libglfw_real.so.3.5.
 *
 * The game doesn't recreate swapchains when the compositor resizes the window.
 * On Wayland the compositor controls window size, causing swapchain/surface
 * extent mismatch → stretching and GPU issues.
 *
 * Strategy: lock each window's size via glfwSetWindowSizeLimits(min==max).
 * The compositor cannot resize the window away from the game's intended size.
 * When the game calls glfwSetWindowSize, we update the limits to match.
 *
 * - Locks window size via min==max size limits (compositor can't override)
 * - Tracks game vs real size; scales cursor coords if they ever diverge
 * - Suppresses Wayland-unsupported features (position, floating, errors)
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>

/* GLFW types */
typedef struct GLFWwindow  GLFWwindow;
typedef struct GLFWmonitor GLFWmonitor;
typedef void (*GLFWcursorposfun)(GLFWwindow*, double, double);
typedef void (*GLFWwindowsizefun)(GLFWwindow*, int, int);
typedef void (*GLFWframebuffersizefun)(GLFWwindow*, int, int);
typedef void (*GLFWerrorfun)(int, const char*);

/* GLFW constants */
#define GLFW_FLOATING           0x00020007
#define GLFW_DONT_CARE          -1
#define GLFW_WAYLAND_APP_ID     0x00026001

#define MAX_WINDOWS 32

/* Shared framebuffer size for the Vulkan layer to read.
 * We use a POSIX shared memory segment so the layer (loaded by the Vulkan loader
 * in the same process but without symbol visibility) can find it.
 *
 * Per-surface layout: each window/surface gets its own fb size entry so the
 * Vulkan layer can return correct currentExtent for each surface independently. */
#define KSA_SHM_NAME "/ksa-glfw-fb-size"
#define KSA_MAX_SURFACES 8

/* VkSurfaceKHR is a non-dispatchable handle (uint64_t) */
typedef uint64_t KsaSurfaceHandle;

typedef struct {
    KsaSurfaceHandle surface;  /* VkSurfaceKHR handle */
    int width;
    int height;
} KsaSurfaceEntry;

typedef struct {
    int resize_allowed;  /* written by Vulkan layer after init, read by GLFW shim */
    int num_surfaces;
    KsaSurfaceEntry surfaces[KSA_MAX_SURFACES];
} KsaShm;

static KsaShm *shared_shm = NULL;

static void init_shared_shm(void) {
    if (shared_shm) return;
    int fd = shm_open(KSA_SHM_NAME, O_CREAT | O_RDWR, 0600);
    if (fd < 0) {
        fprintf(stderr, "[glfw_shim] WARNING: shm_open failed\n");
        return;
    }
    ftruncate(fd, sizeof(KsaShm));
    shared_shm = mmap(NULL, sizeof(KsaShm), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    if (shared_shm == MAP_FAILED) {
        shared_shm = NULL;
        fprintf(stderr, "[glfw_shim] WARNING: mmap failed\n");
        return;
    }
    memset(shared_shm, 0, sizeof(KsaShm));
    fprintf(stderr, "[glfw_shim] shared memory initialized (%zu bytes, %d surface slots)\n",
            sizeof(KsaShm), KSA_MAX_SURFACES);
}

/* Update the shared fb size for a specific surface */
static void set_surface_fb_size(KsaSurfaceHandle surface, int w, int h) {
    if (!shared_shm || !surface) return;
    /* Find existing entry or add new one */
    for (int i = 0; i < shared_shm->num_surfaces; i++) {
        if (shared_shm->surfaces[i].surface == surface) {
            shared_shm->surfaces[i].width = w;
            shared_shm->surfaces[i].height = h;
            return;
        }
    }
    if (shared_shm->num_surfaces < KSA_MAX_SURFACES) {
        int idx = shared_shm->num_surfaces++;
        shared_shm->surfaces[idx].surface = surface;
        shared_shm->surfaces[idx].width = w;
        shared_shm->surfaces[idx].height = h;
        fprintf(stderr, "[glfw_shim] registered surface 0x%lx in shm slot %d (%dx%d)\n",
                (unsigned long)surface, idx, w, h);
    } else {
        fprintf(stderr, "[glfw_shim] WARNING: shm surface slots full (%d)\n", KSA_MAX_SURFACES);
    }
}

static void remove_surface_from_shm(KsaSurfaceHandle surface) {
    if (!shared_shm || !surface) return;
    for (int i = 0; i < shared_shm->num_surfaces; i++) {
        if (shared_shm->surfaces[i].surface == surface) {
            shared_shm->surfaces[i] = shared_shm->surfaces[--shared_shm->num_surfaces];
            fprintf(stderr, "[glfw_shim] removed surface 0x%lx from shm\n",
                    (unsigned long)surface);
            return;
        }
    }
}

/* ===== Resize state =====
 * Compositor resize callbacks are NEVER forwarded to the game — its handler
 * is destructive (destroys mapped GPU buffers → AccessViolationException).
 * Resizes are handled exclusively via the Vulkan layer's OUT_OF_DATE mechanism.
 * We still track resize_allowed for logging the transition. */
static int resize_allowed_last = 0;

static int is_resize_allowed(void) {
    return shared_shm && shared_shm->resize_allowed;
}

/* ===== Real GLFW function pointers (resolved once) ===== */
static void *real_glfw = NULL;
static int logged_scale = 0;

/* Cached real function pointers */
static void (*real_glfwSetWindowSizeLimits)(GLFWwindow*, int, int, int, int) = NULL;
static void (*real_glfwGetWindowSize)(GLFWwindow*, int*, int*) = NULL;
static void (*real_glfwGetFramebufferSize)(GLFWwindow*, int*, int*) = NULL;
static void (*real_glfwSetWindowSize)(GLFWwindow*, int, int) = NULL;
static GLFWwindow* (*real_glfwCreateWindow)(int, int, const char*, GLFWmonitor*, GLFWwindow*) = NULL;

/* ===== Per-window tracking ===== */
typedef struct {
    GLFWwindow *window;
    /* The size the game intends (from creation or glfwSetWindowSize) */
    int game_w, game_h;
    /* The real compositor size (tracked via callbacks) */
    int real_w, real_h;
    /* Whether the game has established its intended size */
    int game_size_set;
    /* Flag: we're inside a glfwSetWindowSize call (app-initiated) */
    int in_set_size;
    /* Flag: this is the primary (main game) window */
    int is_primary;
    /* Vulkan surface associated with this window (set by glfwCreateWindowSurface) */
    KsaSurfaceHandle surface;
    /* App callbacks */
    GLFWcursorposfun       cursor_cb;
    GLFWwindowsizefun      winsize_cb;
    GLFWframebuffersizefun fbsize_cb;
} WindowEntry;

static GLFWwindow *primary_window = NULL;

static WindowEntry windows[MAX_WINDOWS];
static int num_windows = 0;

static WindowEntry *find_window(GLFWwindow *window) {
    for (int i = 0; i < num_windows; i++)
        if (windows[i].window == window) return &windows[i];
    return NULL;
}

static WindowEntry *find_or_add_window(GLFWwindow *window) {
    WindowEntry *e = find_window(window);
    if (e) return e;
    if (num_windows < MAX_WINDOWS) {
        memset(&windows[num_windows], 0, sizeof(WindowEntry));
        windows[num_windows].window = window;
        return &windows[num_windows++];
    }
    fprintf(stderr, "[glfw_shim] WARNING: too many windows (%d)\n", num_windows);
    return NULL;
}

/* ===== Load real GLFW ===== */
static void ensure_real_glfw(void) {
    if (real_glfw) return;
    real_glfw = dlopen("libglfw_real.so.3.5", RTLD_NOW | RTLD_GLOBAL);
    if (!real_glfw) {
        fprintf(stderr, "[glfw_shim] FATAL: cannot load libglfw_real.so.3.5: %s\n", dlerror());
        exit(1);
    }
    fprintf(stderr, "[glfw_shim] loaded real GLFW from libglfw_real.so.3.5\n");

    init_shared_shm();

    /* Cache function pointers */
    real_glfwSetWindowSizeLimits = dlsym(real_glfw, "glfwSetWindowSizeLimits");
    real_glfwGetWindowSize = dlsym(real_glfw, "glfwGetWindowSize");
    real_glfwGetFramebufferSize = dlsym(real_glfw, "glfwGetFramebufferSize");
    real_glfwSetWindowSize = dlsym(real_glfw, "glfwSetWindowSize");
    real_glfwCreateWindow = dlsym(real_glfw, "glfwCreateWindow");
}

static time_t last_log_cur = 0;

/* Lock or unlock a window's size limits.
 * When locked (min==max), the compositor can't resize the window.
 * When unlocked, the compositor can freely resize. */
static int size_lock_enabled = -1; /* -1 = not checked */

static int is_size_lock_enabled(void) {
    if (size_lock_enabled < 0) {
        const char *env = getenv("KSA_GLFW_LOCK_SIZE");
        size_lock_enabled = (env && atoi(env)) ? 1 : 0;
    }
    return size_lock_enabled;
}

static void lock_window_size(GLFWwindow *window, int w, int h) {
    if (!is_size_lock_enabled()) return;
    if (real_glfwSetWindowSizeLimits) {
        real_glfwSetWindowSizeLimits(window, w, h, w, h);
        fprintf(stderr, "[glfw_shim] locked size %dx%d (min==max)\n", w, h);
    }
}

/* ===== glfwCreateWindow ===== */
GLFWwindow* glfwCreateWindow(int width, int height, const char *title,
                              GLFWmonitor *monitor, GLFWwindow *share) {
    ensure_real_glfw();

    /* Set Wayland app_id so Hyprland windowrules can match on class.
     * The game doesn't set one, leaving it empty. */
    if (!primary_window && title && title[0] != '\0') {
        static void (*real_glfwWindowHintString)(int, const char*) = NULL;
        if (!real_glfwWindowHintString)
            real_glfwWindowHintString = dlsym(real_glfw, "glfwWindowHintString");
        if (real_glfwWindowHintString) {
            real_glfwWindowHintString(GLFW_WAYLAND_APP_ID, "ksa");
            fprintf(stderr, "[glfw_shim] set GLFW_WAYLAND_APP_ID to 'ksa'\n");
        }
    }

    GLFWwindow *win = real_glfwCreateWindow(width, height, title, monitor, share);
    if (win) {
        WindowEntry *entry = find_or_add_window(win);
        if (entry) {
            entry->game_w = width;
            entry->game_h = height;
            entry->game_size_set = 1;
            real_glfwGetWindowSize(win, &entry->real_w, &entry->real_h);

            /* The primary window is the first one with a non-empty title
             * and reasonable size. Secondary windows (ImGui, thumbnails)
             * are small (300x64) with empty titles. */
            if (!primary_window && title && title[0] != '\0' &&
                width >= 640 && height >= 480) {
                primary_window = win;
                entry->is_primary = 1;
                fprintf(stderr, "[glfw_shim] CreateWindow(%p): PRIMARY game=%dx%d real=%dx%d \"%s\"\n",
                        (void*)win, width, height, entry->real_w, entry->real_h, title);
            } else {
                entry->is_primary = 0;
                fprintf(stderr, "[glfw_shim] CreateWindow(%p): secondary game=%dx%d real=%dx%d \"%s\"\n",
                        (void*)win, width, height, entry->real_w, entry->real_h,
                        title ? title : "(null)");
            }

            /* Surface not yet known — will be set by glfwCreateWindowSurface.
             * shm fb size will be written once we know the surface handle. */

            /* Lock the window at this size — compositor can't override */
            lock_window_size(win, width, height);
        }
    }
    return win;
}

/* ===== glfwCreateWindowSurface — bridge GLFW windows to Vulkan surfaces ===== */
/* This is the key correlation point: we learn which VkSurfaceKHR belongs to
 * which GLFWwindow, so we can write per-surface fb sizes to shared memory. */
int glfwCreateWindowSurface(void *instance, GLFWwindow *window,
                            const void *allocator, KsaSurfaceHandle *surface) {
    ensure_real_glfw();
    static int (*fn)(void*, GLFWwindow*, const void*, KsaSurfaceHandle*) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwCreateWindowSurface");

    int result = fn(instance, window, allocator, surface);
    if (result == 0 /* VK_SUCCESS */ && surface && *surface) {
        WindowEntry *entry = find_window(window);
        if (entry) {
            entry->surface = *surface;
            /* Write initial fb size to shm for this surface */
            int fb_w = entry->real_w, fb_h = entry->real_h;
            if (real_glfwGetFramebufferSize)
                real_glfwGetFramebufferSize(window, &fb_w, &fb_h);
            set_surface_fb_size(*surface, fb_w, fb_h);
            fprintf(stderr, "[glfw_shim] CreateWindowSurface(%p): surface=0x%lx fb=%dx%d%s\n",
                    (void*)window, (unsigned long)*surface, fb_w, fb_h,
                    entry->is_primary ? " PRIMARY" : "");
        } else {
            fprintf(stderr, "[glfw_shim] CreateWindowSurface(%p): surface=0x%lx (window not tracked!)\n",
                    (void*)window, (unsigned long)*surface);
        }
    }
    return result;
}

/* ===== glfwDestroySurface — clean up surface from shm ===== */
void glfwDestroySurface(void *instance, KsaSurfaceHandle surface,
                        const void *allocator) {
    ensure_real_glfw();
    static void (*fn)(void*, KsaSurfaceHandle, const void*) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwDestroySurface");
    /* Note: GLFW doesn't have glfwDestroySurface — the game uses vkDestroySurfaceKHR.
     * This wrapper won't be called unless the game goes through GLFW. */
    remove_surface_from_shm(surface);
    if (fn) fn(instance, surface, allocator);
}

/* ===== glfwPollEvents ===== */
void glfwPollEvents(void) {
    ensure_real_glfw();
    static void (*fn)(void) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwPollEvents");
    fn();

    /* Log resize_allowed transition for diagnostics */
    int allowed_now = is_resize_allowed();
    if (allowed_now && !resize_allowed_last) {
        fprintf(stderr, "[glfw_shim] resize_allowed=1 (submit threshold reached). "
                "All resizes handled via Vulkan OUT_OF_DATE.\n");
    }
    resize_allowed_last = allowed_now;
}

/* ===== glfwSetWindowSize — app-initiated resize ===== */
void glfwSetWindowSize(GLFWwindow *window, int width, int height) {
    ensure_real_glfw();

    WindowEntry *entry = find_or_add_window(window);
    if (entry) {
        entry->game_w = width;
        entry->game_h = height;
        entry->game_size_set = 1;
        entry->in_set_size = 1;
        fprintf(stderr, "[glfw_shim] SetWindowSize(%p): %dx%d (game-initiated)\n",
                (void*)window, width, height);
    }

    /* Update limits BEFORE the resize so compositor accepts the new size */
    lock_window_size(window, width, height);

    real_glfwSetWindowSize(window, width, height);

    if (entry) {
        real_glfwGetWindowSize(window, &entry->real_w, &entry->real_h);
        entry->in_set_size = 0;
        fprintf(stderr, "[glfw_shim] SetWindowSize(%p): after call real=%dx%d\n",
                (void*)window, entry->real_w, entry->real_h);
    }
}

/* ===== glfwSetWindowSizeLimits — intercept so game can't unlock ===== */
void glfwSetWindowSizeLimits(GLFWwindow *window, int minW, int minH,
                              int maxW, int maxH) {
    ensure_real_glfw();

    WindowEntry *entry = find_window(window);
    if (is_size_lock_enabled() && entry && entry->game_size_set) {
        /* Size lock active: override to keep min==max at game's intended size */
        fprintf(stderr, "[glfw_shim] SetWindowSizeLimits(%p): game requested min=%dx%d max=%dx%d"
                " — overriding to locked %dx%d\n",
                (void*)window, minW, minH, maxW, maxH,
                entry->game_w, entry->game_h);
        real_glfwSetWindowSizeLimits(window,
            entry->game_w, entry->game_h,
            entry->game_w, entry->game_h);
    } else {
        /* Pass through */
        real_glfwSetWindowSizeLimits(window, minW, minH, maxW, maxH);
    }
}

/* ===== glfwGetWindowSize — return game's intended size (locked) or real size (unlocked) ===== */
void glfwGetWindowSize(GLFWwindow *window, int *width, int *height) {
    ensure_real_glfw();

    WindowEntry *entry = find_window(window);
    if (is_size_lock_enabled() && entry && entry->game_size_set) {
        if (width)  *width  = entry->game_w;
        if (height) *height = entry->game_h;
    } else {
        real_glfwGetWindowSize(window, width, height);
    }
}

/* ===== glfwGetFramebufferSize — return game's intended size (locked) or real size (unlocked) ===== */
void glfwGetFramebufferSize(GLFWwindow *window, int *width, int *height) {
    ensure_real_glfw();

    /* At scale 1.0, framebuffer == window size. */
    WindowEntry *entry = find_window(window);
    if (is_size_lock_enabled() && entry && entry->game_size_set) {
        if (width)  *width  = entry->game_w;
        if (height) *height = entry->game_h;
    } else {
        real_glfwGetFramebufferSize(window, width, height);
    }
}

/* ===== glfwGetWindowContentScale ===== */
void glfwGetWindowContentScale(GLFWwindow *window, float *xscale, float *yscale) {
    ensure_real_glfw();
    static void (*fn)(GLFWwindow*, float*, float*) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwGetWindowContentScale");
    fn(window, xscale, yscale);
    if (!logged_scale) {
        logged_scale = 1;
        fprintf(stderr, "[glfw_shim] ContentScale: %.4f x %.4f\n",
                xscale ? *xscale : -1.0f, yscale ? *yscale : -1.0f);
    }
}

/* ===== glfwGetCursorPos — scale from real window to game coords ===== */
void glfwGetCursorPos(GLFWwindow *window, double *xpos, double *ypos) {
    ensure_real_glfw();
    static void (*fn)(GLFWwindow*, double*, double*) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwGetCursorPos");
    fn(window, xpos, ypos);

    /* Safety net: scale cursor if real != game (shouldn't happen with locked size) */
    WindowEntry *entry = find_window(window);
    if (entry && entry->game_size_set && entry->real_w > 0 && entry->real_h > 0 &&
        (entry->real_w != entry->game_w || entry->real_h != entry->game_h)) {
        if (xpos) *xpos = *xpos * (double)entry->game_w / (double)entry->real_w;
        if (ypos) *ypos = *ypos * (double)entry->game_h / (double)entry->real_h;
    }

    time_t now = time(NULL);
    if (now != last_log_cur) {
        last_log_cur = now;
        fprintf(stderr, "[glfw_shim] GetCursorPos(%p): %.1f,%.1f (game=%dx%d real=%dx%d)\n",
                (void*)window,
                xpos ? *xpos : -1.0, ypos ? *ypos : -1.0,
                entry ? entry->game_w : -1, entry ? entry->game_h : -1,
                entry ? entry->real_w : -1, entry ? entry->real_h : -1);
    }
}

/* ===== Cursor callback wrapper — scale coordinates if needed ===== */
static void cursor_pos_wrapper(GLFWwindow *window, double xpos, double ypos) {
    WindowEntry *entry = find_window(window);
    if (entry && entry->cursor_cb) {
        if (entry->game_size_set && entry->real_w > 0 && entry->real_h > 0 &&
            (entry->real_w != entry->game_w || entry->real_h != entry->game_h)) {
            xpos = xpos * (double)entry->game_w / (double)entry->real_w;
            ypos = ypos * (double)entry->game_h / (double)entry->real_h;
        }
        entry->cursor_cb(window, xpos, ypos);
    }
}

GLFWcursorposfun glfwSetCursorPosCallback(GLFWwindow *window, GLFWcursorposfun callback) {
    ensure_real_glfw();
    static GLFWcursorposfun (*fn)(GLFWwindow*, GLFWcursorposfun) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwSetCursorPosCallback");

    WindowEntry *entry = find_or_add_window(window);
    GLFWcursorposfun prev = entry ? entry->cursor_cb : NULL;
    if (entry) entry->cursor_cb = callback;

    fn(window, callback ? cursor_pos_wrapper : NULL);
    return prev;
}

/* ===== Window size callback — track real size, forward all ===== */
static void winsize_wrapper(GLFWwindow *window, int width, int height) {
    WindowEntry *entry = find_window(window);
    if (!entry) return;

    int old_real_w = entry->real_w, old_real_h = entry->real_h;
    entry->real_w = width;
    entry->real_h = height;

    if (entry->in_set_size) {
        /* App-initiated — update game size and forward */
        entry->game_w = width;
        entry->game_h = height;
        fprintf(stderr, "[glfw_shim] WindowSizeCallback(%p): %dx%d (app-initiated)\n",
                (void*)window, width, height);
        if (entry->winsize_cb)
            entry->winsize_cb(window, width, height);
    } else if (is_size_lock_enabled()) {
        /* Size lock active: compositor tried to resize — suppress and re-lock. */
        fprintf(stderr, "[glfw_shim] WindowSizeCallback(%p): %dx%d (compositor! was %dx%d, re-locking to %dx%d)\n",
                (void*)window, width, height, old_real_w, old_real_h,
                entry->game_w, entry->game_h);
        lock_window_size(window, entry->game_w, entry->game_h);
    } else if (entry->is_primary) {
        /* PRIMARY window: suppress compositor resize callbacks.
         * The game's primary resize handler is destructive — it destroys mapped GPU
         * buffers that PlanetRenderer.UpdateUvOffsets still holds CPU pointers to.
         * Resizes are handled via the Vulkan layer's OUT_OF_DATE mechanism instead. */
        entry->real_w = width;
        entry->real_h = height;
        static int suppress_log_count = 0;
        if (suppress_log_count < 5 || suppress_log_count % 100 == 0)
            fprintf(stderr, "[glfw_shim] WindowSizeCallback(%p): %dx%d (compositor, suppressed — primary resize handler is destructive) [#%d]\n",
                    (void*)window, width, height, suppress_log_count);
        suppress_log_count++;
    } else {
        /* SECONDARY windows: forward compositor resize callbacks.
         * Secondary windows (ImGui popups, thumbnails) have simple renderers
         * that handle resizes correctly. They need the callback to recreate
         * their swapchains at the new size. */
        entry->game_w = width;
        entry->game_h = height;
        fprintf(stderr, "[glfw_shim] WindowSizeCallback(%p): %dx%d (compositor, forwarded — secondary window)\n",
                (void*)window, width, height);
        if (entry->winsize_cb)
            entry->winsize_cb(window, width, height);
    }
}

GLFWwindowsizefun glfwSetWindowSizeCallback(GLFWwindow *window, GLFWwindowsizefun callback) {
    ensure_real_glfw();
    static GLFWwindowsizefun (*fn)(GLFWwindow*, GLFWwindowsizefun) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwSetWindowSizeCallback");

    WindowEntry *entry = find_or_add_window(window);
    GLFWwindowsizefun prev = entry ? entry->winsize_cb : NULL;
    if (entry) entry->winsize_cb = callback;

    fn(window, callback ? winsize_wrapper : NULL);
    return prev;
}

/* ===== Framebuffer size callback — track real size, forward app-initiated ===== */
static void fbsize_wrapper(GLFWwindow *window, int width, int height) {
    WindowEntry *entry = find_window(window);
    if (!entry) return;

    entry->real_w = width;
    entry->real_h = height;

    /* Update shm for this window's surface so the Vulkan layer sees the
     * correct fb size per-surface. */
    if (entry->surface)
        set_surface_fb_size(entry->surface, width, height);

    if (entry->in_set_size) {
        entry->game_w = width;
        entry->game_h = height;
        fprintf(stderr, "[glfw_shim] FbSizeCallback(%p): %dx%d (app-initiated)\n",
                (void*)window, width, height);
        if (entry->fbsize_cb)
            entry->fbsize_cb(window, width, height);
    } else if (is_size_lock_enabled()) {
        fprintf(stderr, "[glfw_shim] FbSizeCallback(%p): %dx%d (compositor, suppressed — size locked)\n",
                (void*)window, width, height);
    } else if (entry->is_primary) {
        /* PRIMARY window: suppress — handled via Vulkan OUT_OF_DATE */
        static int fb_suppress_log_count = 0;
        if (fb_suppress_log_count < 5 || fb_suppress_log_count % 100 == 0)
            fprintf(stderr, "[glfw_shim] FbSizeCallback(%p): %dx%d (compositor, suppressed — primary, handled via OUT_OF_DATE) [#%d]\n",
                    (void*)window, width, height, fb_suppress_log_count);
        fb_suppress_log_count++;
    } else {
        /* SECONDARY windows: forward to game so it can recreate swapchain */
        entry->game_w = width;
        entry->game_h = height;
        fprintf(stderr, "[glfw_shim] FbSizeCallback(%p): %dx%d (compositor, forwarded — secondary window)\n",
                (void*)window, width, height);
        if (entry->fbsize_cb)
            entry->fbsize_cb(window, width, height);
    }
}

GLFWframebuffersizefun glfwSetFramebufferSizeCallback(GLFWwindow *window,
                                                       GLFWframebuffersizefun callback) {
    ensure_real_glfw();
    static GLFWframebuffersizefun (*fn)(GLFWwindow*, GLFWframebuffersizefun) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwSetFramebufferSizeCallback");

    WindowEntry *entry = find_or_add_window(window);
    GLFWframebuffersizefun prev = entry ? entry->fbsize_cb : NULL;
    if (entry) {
        entry->fbsize_cb = callback;
        fprintf(stderr, "[glfw_shim] SetFramebufferSizeCallback(%p): %p -> %p\n",
                (void*)window, (void*)prev, (void*)callback);
    }

    fn(window, callback ? fbsize_wrapper : NULL);
    return prev;
}

/* ===== Suppress Wayland position noise ===== */
void glfwGetWindowPos(GLFWwindow *window, int *xpos, int *ypos) {
    if (xpos) *xpos = 0;
    if (ypos) *ypos = 0;
}

void glfwSetWindowPos(GLFWwindow *window, int xpos, int ypos) {
    /* no-op on Wayland */
}

/* ===== Suppress unsupported window attributes ===== */
void glfwSetWindowAttrib(GLFWwindow *window, int attrib, int value) {
    ensure_real_glfw();
    static void (*fn)(GLFWwindow*, int, int) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwSetWindowAttrib");
    if (attrib == GLFW_FLOATING) return;
    fn(window, attrib, value);
}

int glfwGetWindowAttrib(GLFWwindow *window, int attrib) {
    ensure_real_glfw();
    static int (*fn)(GLFWwindow*, int) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwGetWindowAttrib");
    if (attrib == GLFW_FLOATING) return 0;
    return fn(window, attrib);
}

/* ===== GLFW error callback — filter Wayland noise ===== */
static GLFWerrorfun app_error_cb = NULL;

static void error_wrapper(int code, const char *desc) {
    if (code == 65548 || code == 65547) {
        fprintf(stderr, "[glfw_shim] suppressed GLFW error %d: %s\n", code, desc);
        return;
    }
    if (app_error_cb)
        app_error_cb(code, desc);
}

GLFWerrorfun glfwSetErrorCallback(GLFWerrorfun callback) {
    ensure_real_glfw();
    static GLFWerrorfun (*fn)(GLFWerrorfun) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwSetErrorCallback");
    GLFWerrorfun prev = app_error_cb;
    app_error_cb = callback;
    fn(error_wrapper);
    return prev;
}

/* ===== glfwSetWindowMonitor — intercept borderless/fullscreen mode switches ===== */
/* Borderless mode calls glfwSetWindowMonitor(win, monitor, 0, 0, w, h, rate).
 * Windowed mode calls glfwSetWindowMonitor(win, NULL, x, y, w, h, GLFW_DONT_CARE).
 *
 * The game's resize path has a use-after-free bug: it destroys render targets
 * (depth buffer, etc.) while the current frame's command buffer is still in flight,
 * then the render loop tries to write to the freed mapped memory → crash.
 *
 * Strategy: allow the mode switch but update our tracked game size so the shim
 * stays consistent. The Vulkan layer's wait-before-destroy protects the GPU side.
 */
void glfwSetWindowMonitor(GLFWwindow *window, GLFWmonitor *monitor,
                          int xpos, int ypos, int width, int height, int refreshRate) {
    ensure_real_glfw();
    static void (*fn)(GLFWwindow*, GLFWmonitor*, int, int, int, int, int) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwSetWindowMonitor");

    WindowEntry *entry = find_or_add_window(window);
    if (entry) {
        fprintf(stderr, "[glfw_shim] SetWindowMonitor(%p): monitor=%p %dx%d@%d (current game=%dx%d)\n",
                (void*)window, (void*)monitor, width, height, refreshRate,
                entry->game_w, entry->game_h);

        /* Update game size to the requested size */
        entry->game_w = width;
        entry->game_h = height;
        entry->game_size_set = 1;
        entry->in_set_size = 1;
    }

    /* Unlock size limits before the mode change so the compositor can resize */
    if (real_glfwSetWindowSizeLimits)
        real_glfwSetWindowSizeLimits(window, GLFW_DONT_CARE, GLFW_DONT_CARE,
                                     GLFW_DONT_CARE, GLFW_DONT_CARE);

    fn(window, monitor, xpos, ypos, width, height, refreshRate);

    if (entry) {
        real_glfwGetWindowSize(window, &entry->real_w, &entry->real_h);
        entry->in_set_size = 0;
        fprintf(stderr, "[glfw_shim] SetWindowMonitor(%p): after call real=%dx%d, re-locking\n",
                (void*)window, entry->real_w, entry->real_h);

        /* Re-lock at the new size */
        lock_window_size(window, entry->game_w, entry->game_h);
    }
}

/* ===== Clean up ===== */
void glfwDestroyWindow(GLFWwindow *window) {
    ensure_real_glfw();
    static void (*fn)(GLFWwindow*) = NULL;
    if (!fn) fn = dlsym(real_glfw, "glfwDestroyWindow");

    for (int i = 0; i < num_windows; i++) {
        if (windows[i].window == window) {
            fprintf(stderr, "[glfw_shim] DestroyWindow(%p) surface=0x%lx\n",
                    (void*)window, (unsigned long)windows[i].surface);
            if (windows[i].surface)
                remove_surface_from_shm(windows[i].surface);
            windows[i] = windows[--num_windows];
            break;
        }
    }
    fn(window);
}
