/*
 * Vulkan layer that:
 * 1. Fixes maxImageCount == 0 (unlimited) being mishandled by applications
 *    that treat it as a hard upper bound. Replaces 0 with 16.
 * 2. Prevents VK_ERROR_DEVICE_LOST on resize by intercepting
 *    vkAcquireNextImageKHR and returning VK_ERROR_OUT_OF_DATE_KHR when the
 *    surface extent has changed since the swapchain was created.
 * 3. Prevents GPU faults from use-after-free by:
 *    a) Calling vkDeviceWaitIdle before destroying resources with pending work
 *    b) Forcing sync-after-every-submit during swapchain recreation grace period
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <vulkan/vulkan.h>
#include <vulkan/vk_layer.h>

#ifndef VK_LAYER_EXPORT
#define VK_LAYER_EXPORT __attribute__((visibility("default")))
#endif

#define FIX_MAX_IMAGE_COUNT 16
#define MAX_SWAPCHAINS 16

/* ===== Resource lifetime tracking ===== */
#define MAX_ALLOCS 4096
#define MAX_IMAGES 4096
#define MAX_BUFFERS 4096

typedef struct {
    VkDeviceMemory memory;
    VkDeviceSize size;
    uint32_t memory_type_index;
    uint64_t alloc_submit_id;
} AllocEntry;

typedef struct {
    VkImage image;
    uint32_t width, height;
    VkFormat format;
    VkImageUsageFlags usage;
    uint64_t create_submit_id;
} ImageEntry;

typedef struct {
    VkBuffer buffer;
    VkDeviceSize size;
    VkBufferUsageFlags usage;
    uint64_t create_submit_id;
} BufferEntry;

static AllocEntry tracked_allocs[MAX_ALLOCS];
static int num_allocs = 0;
static ImageEntry tracked_images[MAX_IMAGES];
static int num_images = 0;
static BufferEntry tracked_buffers[MAX_BUFFERS];
static int num_buffers = 0;

static uint64_t global_submit_id = 0;
static uint64_t last_waited_submit_id = 0;

/* ===== Mapped memory tracking =====
 * Track vkMapMemory/vkUnmapMemory to detect when the game frees memory
 * that still has an active CPU mapping. If we let the free go through,
 * the game's CPU-side code (e.g. PlanetRenderer.GenerateMeshData) will
 * crash with AccessViolationException when it writes through the stale
 * pointer. We prevent this by refusing to free mapped memory. */
#define MAX_MAPPED 2048
#define UNMAP_GRACE_SUBMITS 1200  /* keep recently-unmapped memory alive for ~10s */
typedef struct {
    VkDeviceMemory memory;
    VkDeviceSize size;      /* for logging */
    uint64_t unmap_submit_id; /* 0 = still mapped, >0 = unmapped at this submit */
    int free_pending;       /* 1 = game called vkFreeMemory, deferred until grace expires */
    VkDevice free_device;   /* device to pass to real vkFreeMemory */
} MappedEntry;

static MappedEntry tracked_mapped[MAX_MAPPED];
static int num_mapped = 0;
static uint64_t leaked_mapped_bytes = 0;  /* total bytes kept alive */

/* Returns 1 if memory is mapped or was recently unmapped (within grace period) */
static int is_memory_mapped(VkDeviceMemory memory) {
    for (int i = 0; i < num_mapped; i++) {
        if (tracked_mapped[i].memory == memory) {
            /* Still actively mapped (unmap suppressed) */
            if (tracked_mapped[i].unmap_submit_id == 0)
                return 1;
            /* Unmapped within grace period */
            if (global_submit_id - tracked_mapped[i].unmap_submit_id < UNMAP_GRACE_SUBMITS)
                return 1;
            /* Grace period expired — remove from tracking */
            tracked_mapped[i] = tracked_mapped[--num_mapped];
            return 0;
        }
    }
    return 0;
}

/* flush_deferred_mapped implemented below after next_UnmapMemory/next_FreeMemory declarations */

static VkDeviceSize get_mapped_size(VkDeviceMemory memory) {
    for (int i = 0; i < num_mapped; i++)
        if (tracked_mapped[i].memory == memory) return tracked_mapped[i].size;
    return 0;
}

static int resource_tracking_enabled = -1;

static int is_tracking_enabled(void) {
    if (resource_tracking_enabled < 0) {
        const char *env = getenv("VK_KSA_TRACK_RESOURCES");
        resource_tracking_enabled = (env && atoi(env)) ? 1 : 0;
        if (resource_tracking_enabled)
            fprintf(stderr, "[vk_layer] Resource lifetime tracking ENABLED\n");
    }
    return resource_tracking_enabled;
}

/* ===== Forward declarations ===== */
static void maybe_signal_resize_allowed(void);
static void flush_deferred_swapchains(void);
static void flush_deferred_mapped(void);
static PFN_vkDestroySwapchainKHR next_DestroySwapchain;
static PFN_vkFreeMemory next_FreeMemory;
static PFN_vkDestroyBuffer next_DestroyBuffer;
static PFN_vkDestroyImage next_DestroyImage;
static PFN_vkDeviceWaitIdle next_DeviceWaitIdle;
static PFN_vkUnmapMemory next_UnmapMemory;

/* Flush expired deferred frees: unmap + free memory whose grace period has expired */
static void flush_deferred_mapped(void) {
    int i = 0;
    while (i < num_mapped) {
        if (tracked_mapped[i].free_pending &&
            tracked_mapped[i].unmap_submit_id > 0 &&
            global_submit_id - tracked_mapped[i].unmap_submit_id >= UNMAP_GRACE_SUBMITS) {
            VkDeviceMemory mem = tracked_mapped[i].memory;
            VkDevice dev = tracked_mapped[i].free_device;
            VkDeviceSize sz = tracked_mapped[i].size;
            leaked_mapped_bytes -= (sz <= leaked_mapped_bytes ? sz : leaked_mapped_bytes);
            fprintf(stderr, "[vk_layer] DEFERRED-FREE: memory %p size=%lu (grace expired, pending=%lu bytes)\n",
                    (void*)(uintptr_t)mem, (unsigned long)sz,
                    (unsigned long)leaked_mapped_bytes);
            /* Now do the real unmap + free */
            next_UnmapMemory(dev, mem);
            next_FreeMemory(dev, mem, NULL);
            tracked_mapped[i] = tracked_mapped[--num_mapped];
        } else {
            i++;
        }
    }
}

/* ===== Usage flag decoders for logging ===== */
static const char* decode_buf_usage(VkBufferUsageFlags u, char *buf, size_t len) {
    buf[0] = '\0';
    if (u & VK_BUFFER_USAGE_TRANSFER_SRC_BIT) strncat(buf, "XFER_SRC|", len-strlen(buf)-1);
    if (u & VK_BUFFER_USAGE_TRANSFER_DST_BIT) strncat(buf, "XFER_DST|", len-strlen(buf)-1);
    if (u & VK_BUFFER_USAGE_UNIFORM_TEXEL_BUFFER_BIT) strncat(buf, "UNI_TEXEL|", len-strlen(buf)-1);
    if (u & VK_BUFFER_USAGE_STORAGE_TEXEL_BUFFER_BIT) strncat(buf, "STOR_TEXEL|", len-strlen(buf)-1);
    if (u & VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT) strncat(buf, "UBO|", len-strlen(buf)-1);
    if (u & VK_BUFFER_USAGE_STORAGE_BUFFER_BIT) strncat(buf, "SSBO|", len-strlen(buf)-1);
    if (u & VK_BUFFER_USAGE_INDEX_BUFFER_BIT) strncat(buf, "INDEX|", len-strlen(buf)-1);
    if (u & VK_BUFFER_USAGE_VERTEX_BUFFER_BIT) strncat(buf, "VERTEX|", len-strlen(buf)-1);
    if (u & VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT) strncat(buf, "INDIRECT|", len-strlen(buf)-1);
    size_t sl = strlen(buf);
    if (sl > 0 && buf[sl-1] == '|') buf[sl-1] = '\0';
    if (buf[0] == '\0') snprintf(buf, len, "0x%x", u);
    return buf;
}

static const char* decode_img_usage(VkImageUsageFlags u, char *buf, size_t len) {
    buf[0] = '\0';
    if (u & VK_IMAGE_USAGE_TRANSFER_SRC_BIT) strncat(buf, "XFER_SRC|", len-strlen(buf)-1);
    if (u & VK_IMAGE_USAGE_TRANSFER_DST_BIT) strncat(buf, "XFER_DST|", len-strlen(buf)-1);
    if (u & VK_IMAGE_USAGE_SAMPLED_BIT) strncat(buf, "SAMPLED|", len-strlen(buf)-1);
    if (u & VK_IMAGE_USAGE_STORAGE_BIT) strncat(buf, "STORAGE|", len-strlen(buf)-1);
    if (u & VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT) strncat(buf, "COLOR_ATT|", len-strlen(buf)-1);
    if (u & VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT) strncat(buf, "DEPTH_ATT|", len-strlen(buf)-1);
    if (u & VK_IMAGE_USAGE_INPUT_ATTACHMENT_BIT) strncat(buf, "INPUT_ATT|", len-strlen(buf)-1);
    size_t sl = strlen(buf);
    if (sl > 0 && buf[sl-1] == '|') buf[sl-1] = '\0';
    if (buf[0] == '\0') snprintf(buf, len, "0x%x", u);
    return buf;
}

/* ===== Swapchain tracking ===== */
typedef struct {
    VkSwapchainKHR swapchain;
    VkSurfaceKHR surface;
    VkExtent2D createExtent;
    /* Per-swapchain resize mismatch state */
    uint32_t last_mismatch_w, last_mismatch_h;
    int mismatch_stable_count;
    uint64_t last_resize_submit_id;
} SwapchainEntry;

static SwapchainEntry tracked_swapchains[MAX_SWAPCHAINS];
static int num_swapchains = 0;

/* primary_surface is retained for logging context only — no longer used for
 * resize gating since each surface now has its own fb size in shared memory. */
static VkSurfaceKHR primary_surface = VK_NULL_HANDLE;

/* ===== Deferred swapchain destruction =====
 * When the game destroys a swapchain, its images are freed immediately.
 * But the game's pre-recorded command buffers / descriptor sets may still
 * reference image views pointing to those images → GPU fault on next submit.
 *
 * We defer the actual destruction for a grace period so the old swapchain
 * images stay alive (VAs remain mapped) until the game has fully transitioned
 * to the new swapchain. */
#define SWAPCHAIN_DEFER_SUBMITS 1200  /* ~10s grace period */
#define MAX_DEFERRED_SWAPCHAINS 16

typedef struct {
    VkSwapchainKHR swapchain;
    VkSurfaceKHR surface;
    VkDevice device;
    uint64_t destroy_submit_id;
} DeferredSwapchain;

static DeferredSwapchain deferred_swapchains[MAX_DEFERRED_SWAPCHAINS];
static int num_deferred = 0;

static void flush_deferred_swapchains(void) {
    int i = 0;
    while (i < num_deferred) {
        if (global_submit_id - deferred_swapchains[i].destroy_submit_id >= SWAPCHAIN_DEFER_SUBMITS) {
            fprintf(stderr, "[vk_layer] deferred destroy: swapchain %p (age=%lu submits)\n",
                    (void*)(uintptr_t)deferred_swapchains[i].swapchain,
                    (unsigned long)(global_submit_id - deferred_swapchains[i].destroy_submit_id));
            next_DestroySwapchain(deferred_swapchains[i].device,
                                  deferred_swapchains[i].swapchain, NULL);
            deferred_swapchains[i] = deferred_swapchains[--num_deferred];
        } else {
            i++;
        }
    }
}

/* Flush ALL deferred swapchains for a specific surface immediately.
 * Called before a surface is destroyed so RADV's WSI doesn't try to
 * dispatch Wayland events on a dead queue. */
static void flush_deferred_swapchains_for_surface(VkSurfaceKHR surface) {
    int i = 0;
    while (i < num_deferred) {
        if (deferred_swapchains[i].surface == surface) {
            fprintf(stderr, "[vk_layer] force-destroy deferred swapchain %p (surface %p being destroyed)\n",
                    (void*)(uintptr_t)deferred_swapchains[i].swapchain,
                    (void*)(uintptr_t)surface);
            if (next_DeviceWaitIdle && deferred_swapchains[i].device)
                next_DeviceWaitIdle(deferred_swapchains[i].device);
            next_DestroySwapchain(deferred_swapchains[i].device,
                                  deferred_swapchains[i].swapchain, NULL);
            deferred_swapchains[i] = deferred_swapchains[--num_deferred];
        } else {
            i++;
        }
    }
}

/* ===== Next layer dispatch ===== */
static PFN_vkGetInstanceProcAddr next_vkGetInstanceProcAddr;
static PFN_vkGetDeviceProcAddr next_vkGetDeviceProcAddr;
static PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR next_GetSurfaceCaps;
static PFN_vkGetPhysicalDeviceSurfaceCapabilities2KHR next_GetSurfaceCaps2;
static PFN_vkCreateSwapchainKHR next_CreateSwapchain;
/* next_DestroySwapchain declared earlier (forward decl for flush_deferred_swapchains) */
static PFN_vkAcquireNextImageKHR next_AcquireNextImage;
static PFN_vkAcquireNextImage2KHR next_AcquireNextImage2;
static PFN_vkDestroySurfaceKHR next_DestroySurface;

static VkPhysicalDevice stashed_physDev;
static VkDevice stashed_device;

/* ===== Framebuffer size from GLFW shim ===== */
#define KSA_SHM_NAME "/ksa-glfw-fb-size"
#define KSA_MAX_SURFACES 8

typedef struct {
    uint64_t surface;  /* VkSurfaceKHR handle */
    int width;
    int height;
} KsaSurfaceEntry;

typedef struct {
    int resize_allowed;  /* set to 1 by this layer after init; read by GLFW shim */
    int num_surfaces;
    KsaSurfaceEntry surfaces[KSA_MAX_SURFACES];
} KsaShm;

static KsaShm *glfw_shm = NULL;
static int glfw_shm_resolved = 0;

static void resolve_shm(void) {
    if (glfw_shm_resolved) return;
    glfw_shm_resolved = 1;
    int fd = shm_open(KSA_SHM_NAME, O_RDWR, 0);
    if (fd < 0) return;
    glfw_shm = mmap(NULL, sizeof(KsaShm), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    if (glfw_shm == MAP_FAILED) {
        glfw_shm = NULL;
        return;
    }
    fprintf(stderr, "[vk_layer] mapped shared memory (read-write, %d surface slots)\n",
            KSA_MAX_SURFACES);
}

/* Look up the framebuffer size for a specific surface.
 * Returns 1 if found, 0 if not. */
static int get_surface_fb_size(VkSurfaceKHR surface, uint32_t *w, uint32_t *h) {
    resolve_shm();
    if (!glfw_shm) return 0;
    uint64_t key = (uint64_t)(uintptr_t)surface;
    for (int i = 0; i < glfw_shm->num_surfaces; i++) {
        if (glfw_shm->surfaces[i].surface == key &&
            glfw_shm->surfaces[i].width > 0 &&
            glfw_shm->surfaces[i].height > 0) {
            *w = (uint32_t)glfw_shm->surfaces[i].width;
            *h = (uint32_t)glfw_shm->surfaces[i].height;
            return 1;
        }
    }
    return 0;
}

static void fix_current_extent(VkSurfaceKHR surface, VkSurfaceCapabilitiesKHR *pCaps) {
    if (pCaps->maxImageCount == 0)
        pCaps->maxImageCount = FIX_MAX_IMAGE_COUNT;

    uint32_t w, h;
    if (pCaps->currentExtent.width == 0xFFFFFFFF &&
        pCaps->currentExtent.height == 0xFFFFFFFF &&
        get_surface_fb_size(surface, &w, &h)) {
        if (w < pCaps->minImageExtent.width) w = pCaps->minImageExtent.width;
        if (w > pCaps->maxImageExtent.width) w = pCaps->maxImageExtent.width;
        if (h < pCaps->minImageExtent.height) h = pCaps->minImageExtent.height;
        if (h > pCaps->maxImageExtent.height) h = pCaps->maxImageExtent.height;
        pCaps->currentExtent.width = w;
        pCaps->currentExtent.height = h;
    }
}

/* ===== Surface caps wrappers ===== */
static VkResult VKAPI_CALL
wrap_GetSurfaceCaps(VkPhysicalDevice physDev, VkSurfaceKHR surface,
                    VkSurfaceCapabilitiesKHR *pCaps)
{
    VkResult res = next_GetSurfaceCaps(physDev, surface, pCaps);
    if (res == VK_SUCCESS)
        fix_current_extent(surface, pCaps);
    return res;
}

static VkResult VKAPI_CALL
wrap_GetSurfaceCaps2(VkPhysicalDevice physDev,
                     const VkPhysicalDeviceSurfaceInfo2KHR *pInfo,
                     VkSurfaceCapabilities2KHR *pCaps)
{
    VkResult res = next_GetSurfaceCaps2(physDev, pInfo, pCaps);
    if (res == VK_SUCCESS)
        fix_current_extent(pInfo ? pInfo->surface : VK_NULL_HANDLE,
                           &pCaps->surfaceCapabilities);
    return res;
}

static PFN_vkQueueSubmit next_QueueSubmit;
static PFN_vkQueueWaitIdle next_QueueWaitIdle;
static PFN_vkAllocateMemory next_AllocateMemory;
static PFN_vkCreateImage next_CreateImage;
static PFN_vkCreateBuffer next_CreateBuffer;
static PFN_vkWaitForFences next_WaitForFences;
static PFN_vkQueueSubmit2 next_QueueSubmit2;
static PFN_vkMapMemory next_MapMemory;
/* next_UnmapMemory declared earlier (forward decl for flush_deferred_mapped) */

/* ===== Sync burst: force vkDeviceWaitIdle after every submit =====
 *
 * The game has a bug where after swapchain recreation, it submits command
 * buffers that still reference destroyed resources (depth image, vertex
 * buffers). The destroy happens correctly (GPU idle), but LATER frames
 * use stale descriptor sets / pre-recorded command buffers.
 *
 * sync_interval=1 (waitIdle after every submit) prevents this because
 * no GPU work is ever in-flight when resources are destroyed, AND no
 * stale command buffer can execute — the GPU finishes each submit before
 * the next one, so by the time the game recreates resources, all old
 * command buffers have completed.
 *
 * We activate this burst automatically on swapchain recreation and
 * keep it active for SYNC_BURST_SUBMITS, then relax.
 *
 * VK_KSA_DEVICE_SYNC_INTERVAL overrides the steady-state interval.
 * Default steady-state: sync every 4 submits (balance of safety + perf).
 */
/* The game has pervasive use-after-free bugs across its entire lifecycle,
 * not just during swapchain recreation. Staging buffers, depth attachments,
 * vertex buffers, and SSBOs are all destroyed with pending GPU work.
 * Combined with a dual-queue architecture (graphics + compute) without
 * proper cross-queue synchronization, only a full device drain after every
 * submit prevents GPU faults.
 *
 * Default steady-state: sync every submit (interval=1).
 * VK_KSA_DEVICE_SYNC_INTERVAL overrides this. */
#define SYNC_BURST_SUBMITS 600  /* ~10 seconds at 60fps */
#define STEADY_STATE_SYNC_INTERVAL 1

static int submit_count = 0;
static int device_sync_interval = 0;  /* current effective interval */
static int steady_sync_interval = STEADY_STATE_SYNC_INTERVAL;
static int device_sync_initialized = 0;

/* Swapchain recreation burst state */
static uint64_t burst_start_submit = 0;
static int burst_active = 0;

static void activate_sync_burst(void) {
    burst_active = 1;
    burst_start_submit = global_submit_id;
    device_sync_interval = 1;
    fprintf(stderr, "[vk_layer] SYNC BURST activated (interval=1 for %d submits)\n",
            SYNC_BURST_SUBMITS);
}

static void check_burst_expiry(void) {
    if (burst_active && global_submit_id - burst_start_submit >= SYNC_BURST_SUBMITS) {
        burst_active = 0;
        device_sync_interval = steady_sync_interval;
        fprintf(stderr, "[vk_layer] SYNC BURST expired, relaxing to interval=%d\n",
                device_sync_interval);
    }
}

/* ===== Resource lifetime wrappers ===== */

static VkResult VKAPI_CALL
wrap_AllocateMemory(VkDevice device, const VkMemoryAllocateInfo *pAllocInfo,
                    const VkAllocationCallbacks *pAllocator, VkDeviceMemory *pMemory)
{
    VkResult res = next_AllocateMemory(device, pAllocInfo, pAllocator, pMemory);
    if (res == VK_SUCCESS && is_tracking_enabled() && num_allocs < MAX_ALLOCS) {
        tracked_allocs[num_allocs].memory = *pMemory;
        tracked_allocs[num_allocs].size = pAllocInfo->allocationSize;
        tracked_allocs[num_allocs].memory_type_index = pAllocInfo->memoryTypeIndex;
        tracked_allocs[num_allocs].alloc_submit_id = global_submit_id;
        num_allocs++;
    }
    return res;
}

/* ===== Map/Unmap tracking ===== */
static VkResult VKAPI_CALL
wrap_MapMemory(VkDevice device, VkDeviceMemory memory,
               VkDeviceSize offset, VkDeviceSize size,
               VkMemoryMapFlags flags, void **ppData)
{
    VkResult res = next_MapMemory(device, memory, offset, size, flags, ppData);
    if (res == VK_SUCCESS && is_tracking_enabled() && memory) {
        /* Track this mapping */
        if (num_mapped < MAX_MAPPED) {
            /* Avoid duplicates; if re-mapped, reset the unmap timestamp */
            int found = 0;
            for (int i = 0; i < num_mapped; i++) {
                if (tracked_mapped[i].memory == memory) {
                    tracked_mapped[i].unmap_submit_id = 0; /* re-mapped */
                    found = 1;
                    break;
                }
            }
            if (!found) {
                /* Look up alloc size for logging */
                VkDeviceSize asize = size;
                for (int i = 0; i < num_allocs; i++) {
                    if (tracked_allocs[i].memory == memory) {
                        asize = tracked_allocs[i].size;
                        break;
                    }
                }
                tracked_mapped[num_mapped].memory = memory;
                tracked_mapped[num_mapped].size = asize;
                tracked_mapped[num_mapped].unmap_submit_id = 0; /* actively mapped */
                tracked_mapped[num_mapped].free_pending = 0;
                tracked_mapped[num_mapped].free_device = VK_NULL_HANDLE;
                num_mapped++;
            }
        }
    }
    return res;
}

static void VKAPI_CALL
wrap_UnmapMemory(VkDevice device, VkDeviceMemory memory)
{
    if (is_tracking_enabled() && memory) {
        /* Don't remove from tracking — mark with unmap timestamp.
         * The grace period keeps the memory "protected" so vkFreeMemory
         * won't free it while PlanetRenderer still holds a stale pointer.
         *
         * CRITICAL: Do NOT forward the unmap to the real driver.
         * The game's C# code (PlanetRenderer.UpdateUvOffsets) holds a cached
         * IntPtr to the mapped region. If we unmap here, the CPU virtual
         * address is invalidated, but the C# code still writes through the
         * stale pointer → AccessViolationException. By suppressing the unmap,
         * the CPU mapping stays valid. The actual unmap happens when we
         * eventually free the memory (after the grace period in wrap_FreeMemory). */
        for (int i = 0; i < num_mapped; i++) {
            if (tracked_mapped[i].memory == memory) {
                tracked_mapped[i].unmap_submit_id = global_submit_id;
                fprintf(stderr, "[vk_layer] SUPPRESS-UNMAP: memory %p (submit_id=%lu, kept mapped for grace period)\n",
                        (void*)(uintptr_t)memory, (unsigned long)global_submit_id);
                return; /* Don't forward to real driver */
            }
        }
    }
    /* Not tracked — forward normally */
    next_UnmapMemory(device, memory);
}

static void VKAPI_CALL
wrap_FreeMemory(VkDevice device, VkDeviceMemory memory,
                const VkAllocationCallbacks *pAllocator)
{
    if (is_tracking_enabled() && memory) {
        uint64_t pending = global_submit_id - last_waited_submit_id;
        VkDeviceSize size = 0;
        uint32_t memtype = 0;
        for (int i = 0; i < num_allocs; i++) {
            if (tracked_allocs[i].memory == memory) {
                size = tracked_allocs[i].size;
                memtype = tracked_allocs[i].memory_type_index;
                tracked_allocs[i] = tracked_allocs[--num_allocs];
                break;
            }
        }
        /* CRITICAL: if this memory has an active CPU mapping (or was recently
         * unmapped within the grace period), do NOT free it.
         * The game's CPU code (PlanetRenderer.UpdateUvOffsets etc.) still
         * holds a cached IntPtr to the mapped region. We suppressed the
         * vkUnmapMemory call so the CPU mapping is still valid. Freeing
         * would invalidate it → AccessViolationException.
         * Mark as free_pending; actual free happens when grace period expires. */
        if (is_memory_mapped(memory)) {
            VkDeviceSize msize = get_mapped_size(memory);
            leaked_mapped_bytes += msize;
            fprintf(stderr, "[vk_layer] KEPT-MAPPED: memory %p size=%lu (free deferred, total pending=%lu bytes)\n",
                    (void*)(uintptr_t)memory, (unsigned long)msize,
                    (unsigned long)leaked_mapped_bytes);
            /* Mark as free_pending — don't remove from tracking */
            for (int i = 0; i < num_mapped; i++) {
                if (tracked_mapped[i].memory == memory) {
                    tracked_mapped[i].free_pending = 1;
                    tracked_mapped[i].free_device = device;
                    break;
                }
            }
            return; /* Don't free — keep memory alive */
        }
        if (pending > 0 && next_DeviceWaitIdle) {
            fprintf(stderr, "[vk_layer] UAF-FREE: memory %p size=%lu memtype=%u pending=%lu\n",
                    (void*)(uintptr_t)memory, (unsigned long)size, memtype,
                    (unsigned long)pending);
            next_DeviceWaitIdle(device);
            last_waited_submit_id = global_submit_id;
        }
    }
    next_FreeMemory(device, memory, pAllocator);
}

static VkResult VKAPI_CALL
wrap_CreateImage(VkDevice device, const VkImageCreateInfo *pCreateInfo,
                 const VkAllocationCallbacks *pAllocator, VkImage *pImage)
{
    VkResult res = next_CreateImage(device, pCreateInfo, pAllocator, pImage);
    if (res == VK_SUCCESS && is_tracking_enabled() && num_images < MAX_IMAGES) {
        tracked_images[num_images].image = *pImage;
        tracked_images[num_images].width = pCreateInfo->extent.width;
        tracked_images[num_images].height = pCreateInfo->extent.height;
        tracked_images[num_images].format = pCreateInfo->format;
        tracked_images[num_images].usage = pCreateInfo->usage;
        tracked_images[num_images].create_submit_id = global_submit_id;
        num_images++;
    }
    return res;
}

static void VKAPI_CALL
wrap_DestroyImage(VkDevice device, VkImage image,
                  const VkAllocationCallbacks *pAllocator)
{
    if (is_tracking_enabled() && image) {
        uint64_t pending = global_submit_id - last_waited_submit_id;
        uint32_t w = 0, h = 0;
        VkFormat fmt = 0;
        VkImageUsageFlags iusage = 0;
        for (int i = 0; i < num_images; i++) {
            if (tracked_images[i].image == image) {
                w = tracked_images[i].width;
                h = tracked_images[i].height;
                fmt = tracked_images[i].format;
                iusage = tracked_images[i].usage;
                tracked_images[i] = tracked_images[--num_images];
                break;
            }
        }
        if (pending > 0 && next_DeviceWaitIdle) {
            char ubuf[256];
            fprintf(stderr, "[vk_layer] UAF-IMG: image %p %ux%u fmt=%d usage=%s pending=%lu\n",
                    (void*)(uintptr_t)image, w, h, fmt,
                    decode_img_usage(iusage, ubuf, sizeof(ubuf)),
                    (unsigned long)pending);
            next_DeviceWaitIdle(device);
            last_waited_submit_id = global_submit_id;
        }
    }
    next_DestroyImage(device, image, pAllocator);
}

static VkResult VKAPI_CALL
wrap_CreateBuffer(VkDevice device, const VkBufferCreateInfo *pCreateInfo,
                  const VkAllocationCallbacks *pAllocator, VkBuffer *pBuffer)
{
    VkResult res = next_CreateBuffer(device, pCreateInfo, pAllocator, pBuffer);
    if (res == VK_SUCCESS && is_tracking_enabled() && num_buffers < MAX_BUFFERS) {
        tracked_buffers[num_buffers].buffer = *pBuffer;
        tracked_buffers[num_buffers].size = pCreateInfo->size;
        tracked_buffers[num_buffers].usage = pCreateInfo->usage;
        tracked_buffers[num_buffers].create_submit_id = global_submit_id;
        num_buffers++;
    }
    return res;
}

static void VKAPI_CALL
wrap_DestroyBuffer(VkDevice device, VkBuffer buffer,
                   const VkAllocationCallbacks *pAllocator)
{
    if (is_tracking_enabled() && buffer) {
        uint64_t pending = global_submit_id - last_waited_submit_id;
        VkDeviceSize bsize = 0;
        VkBufferUsageFlags busage = 0;
        for (int i = 0; i < num_buffers; i++) {
            if (tracked_buffers[i].buffer == buffer) {
                bsize = tracked_buffers[i].size;
                busage = tracked_buffers[i].usage;
                tracked_buffers[i] = tracked_buffers[--num_buffers];
                break;
            }
        }
        if (pending > 0 && next_DeviceWaitIdle) {
            char ubuf[256];
            fprintf(stderr, "[vk_layer] UAF-BUF: buffer %p size=%lu usage=%s pending=%lu\n",
                    (void*)(uintptr_t)buffer, (unsigned long)bsize,
                    decode_buf_usage(busage, ubuf, sizeof(ubuf)),
                    (unsigned long)pending);
            next_DeviceWaitIdle(device);
            last_waited_submit_id = global_submit_id;
        }
    }
    next_DestroyBuffer(device, buffer, pAllocator);
}

static VkResult VKAPI_CALL
wrap_WaitForFences(VkDevice device, uint32_t fenceCount,
                   const VkFence *pFences, VkBool32 waitAll, uint64_t timeout)
{
    VkResult res = next_WaitForFences(device, fenceCount, pFences, waitAll, timeout);
    if (res == VK_SUCCESS && is_tracking_enabled())
        last_waited_submit_id = global_submit_id;
    return res;
}

static VkResult VKAPI_CALL
wrap_DeviceWaitIdle_track(VkDevice device)
{
    VkResult res = next_DeviceWaitIdle(device);
    if (res == VK_SUCCESS && is_tracking_enabled())
        last_waited_submit_id = global_submit_id;
    return res;
}

static VkResult VKAPI_CALL
wrap_QueueWaitIdle_track(VkQueue queue)
{
    VkResult res = next_QueueWaitIdle(queue);
    if (res == VK_SUCCESS && is_tracking_enabled())
        last_waited_submit_id = global_submit_id;
    return res;
}

static VkResult VKAPI_CALL
wrap_QueueSubmit2_track(VkQueue queue, uint32_t submitCount,
                        const VkSubmitInfo2 *pSubmits, VkFence fence)
{
    /* Drain GPU before AND after every submit to ensure no stale references.
     * Pre-submit drain: ensures all previously submitted work is done, so any
     * resources destroyed since the last submit are fully released by the GPU.
     * Post-submit drain: ensures THIS submit's work is done before the game
     * can destroy resources referenced by it. */
    if (device_sync_interval > 0 && next_DeviceWaitIdle && stashed_device)
        next_DeviceWaitIdle(stashed_device);

    VkResult res = next_QueueSubmit2(queue, submitCount, pSubmits, fence);
    if (res == VK_SUCCESS && is_tracking_enabled()) {
        global_submit_id++;
        maybe_signal_resize_allowed();
        flush_deferred_swapchains();
        flush_deferred_mapped();
    }

    /* Post-submit drain */
    if (device_sync_interval > 0 && res == VK_SUCCESS &&
        next_DeviceWaitIdle && stashed_device) {
        submit_count++;
        if (submit_count >= device_sync_interval) {
            submit_count = 0;
            next_DeviceWaitIdle(stashed_device);
            if (is_tracking_enabled())
                last_waited_submit_id = global_submit_id;
            check_burst_expiry();
        }
    }

    return res;
}

static VkResult VKAPI_CALL
wrap_QueueSubmit(VkQueue queue, uint32_t submitCount,
                 const VkSubmitInfo *pSubmits, VkFence fence)
{
    if (!device_sync_initialized) {
        device_sync_initialized = 1;
        const char *env = getenv("VK_KSA_DEVICE_SYNC_INTERVAL");
        if (env) {
            steady_sync_interval = atoi(env);
            if (steady_sync_interval < 0) steady_sync_interval = 0;
        }
        device_sync_interval = steady_sync_interval;
        fprintf(stderr, "[vk_layer] steady-state sync interval: %d\n",
                steady_sync_interval);
    }

    /* Pre-submit drain (see wrap_QueueSubmit2_track for rationale) */
    if (device_sync_interval > 0 && next_DeviceWaitIdle && stashed_device)
        next_DeviceWaitIdle(stashed_device);

    VkResult res = next_QueueSubmit(queue, submitCount, pSubmits, fence);

    if (res == VK_SUCCESS && is_tracking_enabled()) {
        global_submit_id++;
        maybe_signal_resize_allowed();
        flush_deferred_swapchains();
        flush_deferred_mapped();
    }

    /* Post-submit drain */
    if (device_sync_interval > 0 && res == VK_SUCCESS &&
        next_DeviceWaitIdle && stashed_device) {
        submit_count++;
        if (submit_count >= device_sync_interval) {
            submit_count = 0;
            next_DeviceWaitIdle(stashed_device);
            if (is_tracking_enabled())
                last_waited_submit_id = global_submit_id;
            check_burst_expiry();
        }
    }

    return res;
}

/* ===== Swapchain creation tracking ===== */
static VkResult VKAPI_CALL
wrap_CreateSwapchain(VkDevice device,
                     const VkSwapchainCreateInfoKHR *pCreateInfo,
                     const VkAllocationCallbacks *pAllocator,
                     VkSwapchainKHR *pSwapchain)
{
    /* CRITICAL: drain ALL GPU work before swapchain recreation.
     * The game is about to destroy depth images, vertex buffers etc.
     * that may still be referenced by in-flight or pre-recorded command
     * buffers. Force sync_interval=1 for the next SYNC_BURST_SUBMITS
     * to prevent the game from submitting stale command buffers. */
    if (next_DeviceWaitIdle) {
        fprintf(stderr, "[vk_layer] swapchain recreation: draining GPU before create\n");
        next_DeviceWaitIdle(device);
        if (is_tracking_enabled())
            last_waited_submit_id = global_submit_id;
    }
    activate_sync_burst();

    VkResult res = next_CreateSwapchain(device, pCreateInfo, pAllocator, pSwapchain);
    if (res != VK_SUCCESS)
        return res;

    /* Track this swapchain */
    if (num_swapchains < MAX_SWAPCHAINS) {
        tracked_swapchains[num_swapchains].swapchain = *pSwapchain;
        tracked_swapchains[num_swapchains].surface = pCreateInfo->surface;
        tracked_swapchains[num_swapchains].createExtent = pCreateInfo->imageExtent;
        num_swapchains++;

        /* Identify the primary (GLFW window) surface: the first swapchain
         * with a reasonable window-sized extent. Secondary surfaces for ImGui
         * popups, thumbnail renderers etc. are tiny (300x64, 191x32). */
        if (primary_surface == VK_NULL_HANDLE &&
            pCreateInfo->imageExtent.width >= 640 &&
            pCreateInfo->imageExtent.height >= 480) {
            primary_surface = pCreateInfo->surface;
            fprintf(stderr, "[vk_layer] identified primary surface %p (extent %ux%u)\n",
                    (void*)(uintptr_t)primary_surface,
                    pCreateInfo->imageExtent.width,
                    pCreateInfo->imageExtent.height);
        }

        fprintf(stderr, "[vk_layer] tracking swapchain %p (surface %p%s, extent %ux%u)\n",
                (void*)(uintptr_t)*pSwapchain,
                (void*)(uintptr_t)pCreateInfo->surface,
                pCreateInfo->surface == primary_surface ? " PRIMARY" : "",
                pCreateInfo->imageExtent.width,
                pCreateInfo->imageExtent.height);
    }

    return VK_SUCCESS;
}

static void VKAPI_CALL
wrap_DestroySwapchain(VkDevice device, VkSwapchainKHR swapchain,
                      const VkAllocationCallbacks *pAllocator)
{
    /* Look up the surface before removing from tracking */
    VkSurfaceKHR surface = VK_NULL_HANDLE;
    for (int i = 0; i < num_swapchains; i++) {
        if (tracked_swapchains[i].swapchain == swapchain) {
            surface = tracked_swapchains[i].surface;
            tracked_swapchains[i] = tracked_swapchains[--num_swapchains];
            break;
        }
    }

    /* Only defer destruction for the primary surface's swapchains.
     * Primary surface swapchains need deferral because the game's pre-recorded
     * command buffers and stale descriptor sets still reference old swapchain
     * images after recreation.
     *
     * Non-primary (secondary window) swapchains are destroyed immediately
     * (after draining GPU). These windows are short-lived, and deferring
     * their swapchains causes a Wayland abort: glfwDestroyWindow tears down
     * the wl_surface, but the deferred swapchain's WSI present queue still
     * has proxies attached → wl_abort when RADV dispatches events. */
    if (surface == primary_surface && num_deferred < MAX_DEFERRED_SWAPCHAINS) {
        deferred_swapchains[num_deferred].swapchain = swapchain;
        deferred_swapchains[num_deferred].surface = surface;
        deferred_swapchains[num_deferred].device = device;
        deferred_swapchains[num_deferred].destroy_submit_id = global_submit_id;
        num_deferred++;
        fprintf(stderr, "[vk_layer] deferring swapchain %p destruction (surface %p PRIMARY, submit_id=%lu, %d deferred)\n",
                (void*)(uintptr_t)swapchain, (void*)(uintptr_t)surface,
                (unsigned long)global_submit_id, num_deferred);
    } else {
        /* Non-primary or queue full — drain GPU and destroy immediately */
        if (next_DeviceWaitIdle)
            next_DeviceWaitIdle(device);
        fprintf(stderr, "[vk_layer] immediate destroy: swapchain %p (surface %p%s)\n",
                (void*)(uintptr_t)swapchain, (void*)(uintptr_t)surface,
                surface == primary_surface ? " PRIMARY, queue full" : " non-primary");
        next_DestroySwapchain(device, swapchain, pAllocator);
    }
}

/* ===== Acquire interception ===== */
/* Don't fire OUT_OF_DATE until the game has submitted enough frames to be
 * past its initialization phase. The game's init code recreates the swapchain
 * on its own at "Application Initialization Complete", and if our layer
 * ALSO fires OUT_OF_DATE during init, the double-recreation causes
 * PlanetRenderer to crash with AccessViolationException. */
#define RESIZE_SETTLE_FRAMES 30   /* ~0.25s at 120 submits/sec — wait for drag to settle */
#define RESIZE_MIN_SUBMITS 600   /* ~5s at 120 submits/sec — let init finish */
#define RESIZE_COOLDOWN_SUBMITS 120  /* ~1s cooldown between swapchain recreations */

static int resize_allowed_signaled = 0;

static void maybe_signal_resize_allowed(void) {
    if (!resize_allowed_signaled && global_submit_id >= RESIZE_MIN_SUBMITS) {
        resolve_shm();
        if (glfw_shm) {
            glfw_shm->resize_allowed = 1;
            resize_allowed_signaled = 1;
            fprintf(stderr, "[vk_layer] resize_allowed=1 signaled (submit_id=%lu >= %d)\n",
                    (unsigned long)global_submit_id, RESIZE_MIN_SUBMITS);
        }
    }
}

static int check_extent_mismatch(VkSwapchainKHR swapchain) {
    resolve_shm();
    if (!glfw_shm) return 0;

    /* Suppress resize during initialization */
    if (global_submit_id < RESIZE_MIN_SUBMITS) {
        static int suppression_logged = 0;
        if (!suppression_logged) {
            fprintf(stderr, "[vk_layer] suppressing OUT_OF_DATE during init (submit %lu < %d)\n",
                    (unsigned long)global_submit_id, RESIZE_MIN_SUBMITS);
            suppression_logged = 1;
        }
        return 0;
    }

    for (int i = 0; i < num_swapchains; i++) {
        if (tracked_swapchains[i].swapchain == swapchain) {
            SwapchainEntry *sc = &tracked_swapchains[i];

            /* Per-swapchain cooldown */
            if (sc->last_resize_submit_id > 0 &&
                global_submit_id - sc->last_resize_submit_id < RESIZE_COOLDOWN_SUBMITS) {
                return 0;
            }

            /* Look up this surface's fb size from shm */
            uint32_t fb_w, fb_h;
            if (!get_surface_fb_size(sc->surface, &fb_w, &fb_h))
                return 0;  /* Surface not in shm — no GLFW window, skip */

            VkExtent2D old = sc->createExtent;
            if (fb_w == old.width && fb_h == old.height) {
                sc->last_mismatch_w = 0;
                sc->last_mismatch_h = 0;
                sc->mismatch_stable_count = 0;
                return 0;
            }
            if (fb_w == sc->last_mismatch_w && fb_h == sc->last_mismatch_h) {
                sc->mismatch_stable_count++;
            } else {
                sc->last_mismatch_w = fb_w;
                sc->last_mismatch_h = fb_h;
                sc->mismatch_stable_count = 1;
            }
            if (sc->mismatch_stable_count >= RESIZE_SETTLE_FRAMES) {
                fprintf(stderr, "[vk_layer] surface %p: fb %ux%u != swapchain %ux%u "
                        "(stable for %d acquires), returning OUT_OF_DATE\n",
                        (void*)(uintptr_t)sc->surface,
                        fb_w, fb_h, old.width, old.height, sc->mismatch_stable_count);
                sc->mismatch_stable_count = 0;
                sc->last_resize_submit_id = global_submit_id;
                return 1;
            }
            break;
        }
    }
    return 0;
}

static VkResult VKAPI_CALL
wrap_AcquireNextImage(VkDevice device, VkSwapchainKHR swapchain,
                      uint64_t timeout, VkSemaphore semaphore,
                      VkFence fence, uint32_t *pImageIndex)
{
    if (check_extent_mismatch(swapchain))
        return VK_ERROR_OUT_OF_DATE_KHR;
    return next_AcquireNextImage(device, swapchain, timeout, semaphore, fence, pImageIndex);
}

static VkResult VKAPI_CALL
wrap_AcquireNextImage2(VkDevice device,
                       const VkAcquireNextImageInfoKHR *pAcquireInfo,
                       uint32_t *pImageIndex)
{
    if (pAcquireInfo && check_extent_mismatch(pAcquireInfo->swapchain))
        return VK_ERROR_OUT_OF_DATE_KHR;
    if (next_AcquireNextImage2)
        return next_AcquireNextImage2(device, pAcquireInfo, pImageIndex);
    return next_AcquireNextImage(device, pAcquireInfo->swapchain,
        pAcquireInfo->timeout, pAcquireInfo->semaphore,
        pAcquireInfo->fence, pImageIndex);
}

/* ===== Device creation ===== */
static VkResult VKAPI_CALL
wrap_CreateDevice(VkPhysicalDevice physDev,
                  const VkDeviceCreateInfo *pCreateInfo,
                  const VkAllocationCallbacks *pAllocator,
                  VkDevice *pDevice)
{
    VkLayerDeviceCreateInfo *layerInfo = (VkLayerDeviceCreateInfo *)pCreateInfo->pNext;
    while (layerInfo &&
           !(layerInfo->sType == VK_STRUCTURE_TYPE_LOADER_DEVICE_CREATE_INFO &&
             layerInfo->function == VK_LAYER_LINK_INFO))
        layerInfo = (VkLayerDeviceCreateInfo *)layerInfo->pNext;

    if (!layerInfo)
        return VK_ERROR_INITIALIZATION_FAILED;

    PFN_vkGetInstanceProcAddr getInstanceAddr = layerInfo->u.pLayerInfo->pfnNextGetInstanceProcAddr;
    PFN_vkGetDeviceProcAddr getDeviceAddr = layerInfo->u.pLayerInfo->pfnNextGetDeviceProcAddr;
    layerInfo->u.pLayerInfo = layerInfo->u.pLayerInfo->pNext;

    PFN_vkCreateDevice createDevice = (PFN_vkCreateDevice)getInstanceAddr(NULL, "vkCreateDevice");
    VkResult res = createDevice(physDev, pCreateInfo, pAllocator, pDevice);
    if (res != VK_SUCCESS)
        return res;

    next_vkGetDeviceProcAddr = getDeviceAddr;
    stashed_physDev = physDev;
    stashed_device = *pDevice;

    next_CreateSwapchain = (PFN_vkCreateSwapchainKHR)
        getDeviceAddr(*pDevice, "vkCreateSwapchainKHR");
    next_DestroySwapchain = (PFN_vkDestroySwapchainKHR)
        getDeviceAddr(*pDevice, "vkDestroySwapchainKHR");
    next_AcquireNextImage = (PFN_vkAcquireNextImageKHR)
        getDeviceAddr(*pDevice, "vkAcquireNextImageKHR");
    next_AcquireNextImage2 = (PFN_vkAcquireNextImage2KHR)
        getDeviceAddr(*pDevice, "vkAcquireNextImage2KHR");
    next_DeviceWaitIdle = (PFN_vkDeviceWaitIdle)
        getDeviceAddr(*pDevice, "vkDeviceWaitIdle");
    next_QueueSubmit = (PFN_vkQueueSubmit)
        getDeviceAddr(*pDevice, "vkQueueSubmit");
    next_QueueWaitIdle = (PFN_vkQueueWaitIdle)
        getDeviceAddr(*pDevice, "vkQueueWaitIdle");

    next_AllocateMemory = (PFN_vkAllocateMemory)
        getDeviceAddr(*pDevice, "vkAllocateMemory");
    next_FreeMemory = (PFN_vkFreeMemory)
        getDeviceAddr(*pDevice, "vkFreeMemory");
    next_CreateImage = (PFN_vkCreateImage)
        getDeviceAddr(*pDevice, "vkCreateImage");
    next_DestroyImage = (PFN_vkDestroyImage)
        getDeviceAddr(*pDevice, "vkDestroyImage");
    next_CreateBuffer = (PFN_vkCreateBuffer)
        getDeviceAddr(*pDevice, "vkCreateBuffer");
    next_DestroyBuffer = (PFN_vkDestroyBuffer)
        getDeviceAddr(*pDevice, "vkDestroyBuffer");
    next_WaitForFences = (PFN_vkWaitForFences)
        getDeviceAddr(*pDevice, "vkWaitForFences");
    next_QueueSubmit2 = (PFN_vkQueueSubmit2)
        getDeviceAddr(*pDevice, "vkQueueSubmit2");
    next_MapMemory = (PFN_vkMapMemory)
        getDeviceAddr(*pDevice, "vkMapMemory");
    next_UnmapMemory = (PFN_vkUnmapMemory)
        getDeviceAddr(*pDevice, "vkUnmapMemory");

    return VK_SUCCESS;
}

/* ===== Instance creation ===== */
static VkResult VKAPI_CALL
wrap_CreateInstance(const VkInstanceCreateInfo *pCreateInfo,
                    const VkAllocationCallbacks *pAllocator,
                    VkInstance *pInstance)
{
    VkLayerInstanceCreateInfo *layerInfo = (VkLayerInstanceCreateInfo *)pCreateInfo->pNext;
    while (layerInfo &&
           !(layerInfo->sType == VK_STRUCTURE_TYPE_LOADER_INSTANCE_CREATE_INFO &&
             layerInfo->function == VK_LAYER_LINK_INFO))
        layerInfo = (VkLayerInstanceCreateInfo *)layerInfo->pNext;

    if (!layerInfo)
        return VK_ERROR_INITIALIZATION_FAILED;

    PFN_vkGetInstanceProcAddr getAddr = layerInfo->u.pLayerInfo->pfnNextGetInstanceProcAddr;
    layerInfo->u.pLayerInfo = layerInfo->u.pLayerInfo->pNext;

    PFN_vkCreateInstance createInstance = (PFN_vkCreateInstance)getAddr(NULL, "vkCreateInstance");
    VkResult res = createInstance(pCreateInfo, pAllocator, pInstance);
    if (res != VK_SUCCESS)
        return res;

    next_vkGetInstanceProcAddr = getAddr;
    next_GetSurfaceCaps = (PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR)
        getAddr(*pInstance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR");
    next_GetSurfaceCaps2 = (PFN_vkGetPhysicalDeviceSurfaceCapabilities2KHR)
        getAddr(*pInstance, "vkGetPhysicalDeviceSurfaceCapabilities2KHR");
    next_DestroySurface = (PFN_vkDestroySurfaceKHR)
        getAddr(*pInstance, "vkDestroySurfaceKHR");

    return VK_SUCCESS;
}

/* ===== Surface destruction — flush deferred swapchains first ===== */
static void VKAPI_CALL
wrap_DestroySurface(VkInstance instance, VkSurfaceKHR surface,
                    const VkAllocationCallbacks *pAllocator)
{
    if (surface) {
        /* CRITICAL: destroy any deferred swapchains on this surface NOW.
         * If we let them linger, RADV's WSI will try to dispatch Wayland
         * events on the dead wl_surface queue → wl_abort → process killed.
         * The game destroys GLFW windows (which destroys wl_surface) before
         * the deferred swapchain grace period expires. */
        fprintf(stderr, "[vk_layer] DestroySurface %p: flushing deferred swapchains\n",
                (void*)(uintptr_t)surface);
        flush_deferred_swapchains_for_surface(surface);
    }
    next_DestroySurface(instance, surface, pAllocator);
}

/* ===== Proc addr dispatch ===== */
static PFN_vkVoidFunction VKAPI_CALL
wrap_GetInstanceProcAddr(VkInstance instance, const char *pName)
{
    if (!strcmp(pName, "vkCreateInstance"))
        return (PFN_vkVoidFunction)wrap_CreateInstance;
    if (!strcmp(pName, "vkCreateDevice"))
        return (PFN_vkVoidFunction)wrap_CreateDevice;
    if (!strcmp(pName, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR") && next_GetSurfaceCaps)
        return (PFN_vkVoidFunction)wrap_GetSurfaceCaps;
    if (!strcmp(pName, "vkGetPhysicalDeviceSurfaceCapabilities2KHR") && next_GetSurfaceCaps2)
        return (PFN_vkVoidFunction)wrap_GetSurfaceCaps2;
    if (!strcmp(pName, "vkDestroySurfaceKHR") && next_DestroySurface)
        return (PFN_vkVoidFunction)wrap_DestroySurface;

    if (next_vkGetInstanceProcAddr)
        return next_vkGetInstanceProcAddr(instance, pName);
    return NULL;
}

static PFN_vkVoidFunction VKAPI_CALL
wrap_GetDeviceProcAddr(VkDevice device, const char *pName)
{
    if (!strcmp(pName, "vkCreateSwapchainKHR") && next_CreateSwapchain)
        return (PFN_vkVoidFunction)wrap_CreateSwapchain;
    if (!strcmp(pName, "vkDestroySwapchainKHR") && next_DestroySwapchain)
        return (PFN_vkVoidFunction)wrap_DestroySwapchain;
    if (!strcmp(pName, "vkAcquireNextImageKHR") && next_AcquireNextImage)
        return (PFN_vkVoidFunction)wrap_AcquireNextImage;
    if (!strcmp(pName, "vkAcquireNextImage2KHR") && next_AcquireNextImage2)
        return (PFN_vkVoidFunction)wrap_AcquireNextImage2;
    if (!strcmp(pName, "vkQueueSubmit") && next_QueueSubmit)
        return (PFN_vkVoidFunction)wrap_QueueSubmit;
    if (!strcmp(pName, "vkQueueSubmit2") && next_QueueSubmit2)
        return (PFN_vkVoidFunction)wrap_QueueSubmit2_track;

    /* Resource tracking wrappers */
    if (!strcmp(pName, "vkAllocateMemory") && next_AllocateMemory)
        return (PFN_vkVoidFunction)wrap_AllocateMemory;
    if (!strcmp(pName, "vkFreeMemory") && next_FreeMemory)
        return (PFN_vkVoidFunction)wrap_FreeMemory;
    if (!strcmp(pName, "vkMapMemory") && next_MapMemory)
        return (PFN_vkVoidFunction)wrap_MapMemory;
    if (!strcmp(pName, "vkUnmapMemory") && next_UnmapMemory)
        return (PFN_vkVoidFunction)wrap_UnmapMemory;
    if (!strcmp(pName, "vkCreateImage") && next_CreateImage)
        return (PFN_vkVoidFunction)wrap_CreateImage;
    if (!strcmp(pName, "vkDestroyImage") && next_DestroyImage)
        return (PFN_vkVoidFunction)wrap_DestroyImage;
    if (!strcmp(pName, "vkCreateBuffer") && next_CreateBuffer)
        return (PFN_vkVoidFunction)wrap_CreateBuffer;
    if (!strcmp(pName, "vkDestroyBuffer") && next_DestroyBuffer)
        return (PFN_vkVoidFunction)wrap_DestroyBuffer;
    if (!strcmp(pName, "vkWaitForFences") && next_WaitForFences)
        return (PFN_vkVoidFunction)wrap_WaitForFences;
    if (!strcmp(pName, "vkDeviceWaitIdle") && next_DeviceWaitIdle)
        return (PFN_vkVoidFunction)wrap_DeviceWaitIdle_track;
    if (!strcmp(pName, "vkQueueWaitIdle") && next_QueueWaitIdle)
        return (PFN_vkVoidFunction)wrap_QueueWaitIdle_track;

    if (next_vkGetDeviceProcAddr)
        return next_vkGetDeviceProcAddr(device, pName);
    return NULL;
}

/* ===== Layer entry points ===== */
VK_LAYER_EXPORT PFN_vkVoidFunction VKAPI_CALL
vkGetInstanceProcAddr(VkInstance instance, const char *pName)
{
    return wrap_GetInstanceProcAddr(instance, pName);
}

VK_LAYER_EXPORT PFN_vkVoidFunction VKAPI_CALL
vkGetDeviceProcAddr(VkDevice device, const char *pName)
{
    return wrap_GetDeviceProcAddr(device, pName);
}

VK_LAYER_EXPORT VkResult VKAPI_CALL
vkEnumerateInstanceLayerProperties(uint32_t *pPropertyCount,
                                   VkLayerProperties *pProperties)
{
    if (!pProperties) {
        *pPropertyCount = 1;
        return VK_SUCCESS;
    }
    if (*pPropertyCount < 1)
        return VK_INCOMPLETE;

    *pPropertyCount = 1;
    memset(pProperties, 0, sizeof(*pProperties));
    strncpy(pProperties->layerName, "VK_LAYER_KSA_fix_swapchain",
            VK_MAX_EXTENSION_NAME_SIZE);
    pProperties->specVersion = VK_MAKE_VERSION(1, 0, 0);
    pProperties->implementationVersion = 3;
    strncpy(pProperties->description,
            "Fixes maxImageCount=0, resize crashes, and use-after-free",
            VK_MAX_DESCRIPTION_SIZE);
    return VK_SUCCESS;
}

VkResult VKAPI_CALL
vkEnumerateInstanceExtensionProperties(const char *pLayerName,
                                       uint32_t *pPropertyCount,
                                       VkExtensionProperties *pProperties)
{
    (void)pLayerName;
    (void)pProperties;
    *pPropertyCount = 0;
    return VK_SUCCESS;
}
