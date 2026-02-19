/*
 * Vulkan layer that fixes maxImageCount == 0 (unlimited) being mishandled
 * by applications that treat it as a hard upper bound.
 *
 * Per the Vulkan spec, maxImageCount == 0 means there is no limit.
 * This layer replaces 0 with a sensible default (16).
 */

#include <string.h>
#include <vulkan/vulkan.h>
#include <vulkan/vk_layer.h>

#ifndef VK_LAYER_EXPORT
#define VK_LAYER_EXPORT __attribute__((visibility("default")))
#endif

#define FIX_MAX_IMAGE_COUNT 16

/* Next layer dispatch */
static PFN_vkGetInstanceProcAddr next_vkGetInstanceProcAddr;
static PFN_vkGetDeviceProcAddr next_vkGetDeviceProcAddr;
static PFN_vkGetPhysicalDeviceSurfaceCapabilitiesKHR next_GetSurfaceCaps;
static PFN_vkGetPhysicalDeviceSurfaceCapabilities2KHR next_GetSurfaceCaps2;

static VkResult VKAPI_CALL
wrap_GetSurfaceCaps(VkPhysicalDevice physDev, VkSurfaceKHR surface,
                    VkSurfaceCapabilitiesKHR *pCaps)
{
    VkResult res = next_GetSurfaceCaps(physDev, surface, pCaps);
    if (res == VK_SUCCESS && pCaps->maxImageCount == 0)
        pCaps->maxImageCount = FIX_MAX_IMAGE_COUNT;
    return res;
}

static VkResult VKAPI_CALL
wrap_GetSurfaceCaps2(VkPhysicalDevice physDev,
                     const VkPhysicalDeviceSurfaceInfo2KHR *pInfo,
                     VkSurfaceCapabilities2KHR *pCaps)
{
    VkResult res = next_GetSurfaceCaps2(physDev, pInfo, pCaps);
    if (res == VK_SUCCESS && pCaps->surfaceCapabilities.maxImageCount == 0)
        pCaps->surfaceCapabilities.maxImageCount = FIX_MAX_IMAGE_COUNT;
    return res;
}

static VkResult VKAPI_CALL
wrap_CreateDevice(VkPhysicalDevice physDev,
                  const VkDeviceCreateInfo *pCreateInfo,
                  const VkAllocationCallbacks *pAllocator,
                  VkDevice *pDevice)
{
    /* Walk the pNext chain to find the layer device link info */
    VkLayerDeviceCreateInfo *layerInfo = (VkLayerDeviceCreateInfo *)pCreateInfo->pNext;
    while (layerInfo &&
           !(layerInfo->sType == VK_STRUCTURE_TYPE_LOADER_DEVICE_CREATE_INFO &&
             layerInfo->function == VK_LAYER_LINK_INFO))
        layerInfo = (VkLayerDeviceCreateInfo *)layerInfo->pNext;

    if (!layerInfo)
        return VK_ERROR_INITIALIZATION_FAILED;

    PFN_vkGetInstanceProcAddr getInstanceAddr = layerInfo->u.pLayerInfo->pfnNextGetInstanceProcAddr;
    PFN_vkGetDeviceProcAddr getDeviceAddr = layerInfo->u.pLayerInfo->pfnNextGetDeviceProcAddr;
    /* Advance the chain for the next layer */
    layerInfo->u.pLayerInfo = layerInfo->u.pLayerInfo->pNext;

    PFN_vkCreateDevice createDevice = (PFN_vkCreateDevice)getInstanceAddr(NULL, "vkCreateDevice");
    VkResult res = createDevice(physDev, pCreateInfo, pAllocator, pDevice);
    if (res != VK_SUCCESS)
        return res;

    next_vkGetDeviceProcAddr = getDeviceAddr;
    return VK_SUCCESS;
}

static VkResult VKAPI_CALL
wrap_CreateInstance(const VkInstanceCreateInfo *pCreateInfo,
                    const VkAllocationCallbacks *pAllocator,
                    VkInstance *pInstance)
{
    /* Walk the pNext chain to find the layer link info */
    VkLayerInstanceCreateInfo *layerInfo = (VkLayerInstanceCreateInfo *)pCreateInfo->pNext;
    while (layerInfo &&
           !(layerInfo->sType == VK_STRUCTURE_TYPE_LOADER_INSTANCE_CREATE_INFO &&
             layerInfo->function == VK_LAYER_LINK_INFO))
        layerInfo = (VkLayerInstanceCreateInfo *)layerInfo->pNext;

    if (!layerInfo)
        return VK_ERROR_INITIALIZATION_FAILED;

    PFN_vkGetInstanceProcAddr getAddr = layerInfo->u.pLayerInfo->pfnNextGetInstanceProcAddr;
    /* Advance the chain for the next layer */
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

    return VK_SUCCESS;
}

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

    if (next_vkGetInstanceProcAddr)
        return next_vkGetInstanceProcAddr(instance, pName);
    return NULL;
}

static PFN_vkVoidFunction VKAPI_CALL
wrap_GetDeviceProcAddr(VkDevice device, const char *pName)
{
    /* We don't intercept any device-level functions, pass through */
    if (next_vkGetDeviceProcAddr)
        return next_vkGetDeviceProcAddr(device, pName);
    return NULL;
}

/* Layer entry points */
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
    pProperties->implementationVersion = 1;
    strncpy(pProperties->description,
            "Fixes maxImageCount=0 for broken applications",
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
