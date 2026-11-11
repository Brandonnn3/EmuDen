#include "VulkanVideo.h"
#define VK_NO_PROTOTYPES
#include "libretro_vulkan.h"
#include <dlfcn.h>
#include <algorithm>
#include <cstring>
#include <mutex>
#include <stdexcept>
#include <vector>
#include <condition_variable>
#include <exception>
#include <thread>
#if defined(__APPLE__)
#include <TargetConditionals.h>
#include <pthread/qos.h>
#endif
#if TARGET_OS_SIMULATOR
#include <cstdlib>
#include <cstdio>
#include <execinfo.h>
#include <unistd.h>
#include <atomic>
#endif

namespace {
#if TARGET_OS_SIMULATOR
// Opt-in regression capture identifies the recording call before an invalid image reaches Metal.
PFN_vkGetDeviceProcAddr diagnosticDeviceProc = nullptr;
PFN_vkGetInstanceProcAddr diagnosticInstanceProc = nullptr;
PFN_vkCmdPipelineBarrier diagnosticPipelineBarrier = nullptr;
std::atomic_uint64_t diagnosticImageBarriers{0};
VKAPI_ATTR void VKAPI_CALL checkedPipelineBarrier(
    VkCommandBuffer command, VkPipelineStageFlags source, VkPipelineStageFlags destination,
    VkDependencyFlags dependencies, uint32_t memoryCount, const VkMemoryBarrier* memory,
    uint32_t bufferCount, const VkBufferMemoryBarrier* buffers,
    uint32_t imageCount, const VkImageMemoryBarrier* images) {
    for (uint32_t i = 0; i < imageCount; ++i) {
        if (!images || images[i].image == VK_NULL_HANDLE) {
            fprintf(stderr, "GPU VALIDATION: null image barrier %u/%u, stages=%u/%u\n", i, imageCount, source, destination);
            void* stack[32]; const int count = backtrace(stack, 32);
            backtrace_symbols_fd(stack, count, STDERR_FILENO);
            abort();
        }
    }
    if (imageCount && diagnosticImageBarriers.fetch_add(imageCount) == 0)
        fprintf(stderr, "GPU VALIDATION: image-barrier checking active\n");
    diagnosticPipelineBarrier(command, source, destination, dependencies, memoryCount, memory,
                              bufferCount, buffers, imageCount, images);
}
VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL checkedDeviceProc(VkDevice device, const char* name) {
    if (!strcmp(name, "vkCmdPipelineBarrier")) return reinterpret_cast<PFN_vkVoidFunction>(checkedPipelineBarrier);
    return diagnosticDeviceProc(device, name);
}
VKAPI_ATTR PFN_vkVoidFunction VKAPI_CALL checkedInstanceProc(VkInstance instance, const char* name) {
    if (!strcmp(name, "vkGetDeviceProcAddr")) return reinterpret_cast<PFN_vkVoidFunction>(checkedDeviceProc);
    if (!strcmp(name, "vkCmdPipelineBarrier")) return reinterpret_cast<PFN_vkVoidFunction>(checkedPipelineBarrier);
    return diagnosticInstanceProc(instance, name);
}
#endif
void check(VkResult result, const char* operation) {
    if (result != VK_SUCCESS)
        throw std::runtime_error(std::string(operation) + " failed (Vulkan " + std::to_string(result) + ")");
}
}

struct VulkanVideo::Impl {
    std::string libraryPath, name;
    void* library = nullptr;
    retro_hw_render_callback hw{};
    retro_hw_render_context_negotiation_interface_vulkan negotiation{};
    retro_hw_render_interface_vulkan interface{};
    bool contextLive = false, negotiated = false;
    VkInstance instance = VK_NULL_HANDLE;
    retro_vulkan_context context{};
    std::mutex queueMutex;
    retro_vulkan_image image{};
    bool hasImage = false;
    uint32_t sourceQueue = VK_QUEUE_FAMILY_IGNORED;
    std::vector<VkSemaphore> waits;
    std::vector<VkCommandBuffer> coreCommands;
    VkSemaphore signal = VK_NULL_HANDLE;
    struct Readback {
        VkCommandPool pool = VK_NULL_HANDLE;
        VkCommandBuffer command = VK_NULL_HANDLE;
        VkFence fence = VK_NULL_HANDLE;
        VkBuffer buffer = VK_NULL_HANDLE;
        VkDeviceMemory memory = VK_NULL_HANDLE;
        void* mapped = nullptr;
        VkDeviceSize capacity = 0;
        unsigned width = 0, height = 0;
        bool coherent = false, pending = false, bgra = false;
    };
    Readback readback;
    FrameHandler frameHandler;
    std::mutex completionMutex;
    std::condition_variable completion;
    std::thread worker;
    std::exception_ptr workerError;
    bool stopping = false;

    PFN_vkGetInstanceProcAddr getInstanceProc = nullptr;
    PFN_vkGetDeviceProcAddr getDeviceProc = nullptr;
    PFN_vkDestroyInstance destroyInstance = nullptr;
    PFN_vkDestroyDevice destroyDevice = nullptr;
#define DEVICE_FUNCTIONS(F) \
    F(DeviceWaitIdle) F(CreateCommandPool) F(DestroyCommandPool) F(AllocateCommandBuffers) \
    F(ResetCommandPool) F(BeginCommandBuffer) F(EndCommandBuffer) F(CreateFence) \
    F(DestroyFence) F(ResetFences) F(WaitForFences) F(QueueSubmit) F(CreateBuffer) \
    F(DestroyBuffer) F(GetBufferMemoryRequirements) F(AllocateMemory) F(FreeMemory) \
    F(BindBufferMemory) F(MapMemory) F(UnmapMemory) F(InvalidateMappedMemoryRanges) \
    F(CmdPipelineBarrier) F(CmdCopyImageToBuffer)
#define DECLARE(name) PFN_vk##name name = nullptr;
    DEVICE_FUNCTIONS(DECLARE)
#undef DECLARE

    template<class T> T proc(const char* function) {
        auto result = reinterpret_cast<T>(getInstanceProc(instance, function));
        if (!result) throw std::runtime_error(std::string("Missing Vulkan function: ") + function);
        return result;
    }
    template<class T> T deviceProc(const char* function) {
        auto result = reinterpret_cast<T>(getDeviceProc(context.device, function));
        if (!result) throw std::runtime_error(std::string("Missing Vulkan device function: ") + function);
        return result;
    }
    explicit Impl(std::string path, FrameHandler handler) : libraryPath(std::move(path)), frameHandler(std::move(handler)) {}
    ~Impl() {
        if (worker.joinable()) {
            { std::lock_guard<std::mutex> lock(completionMutex); stopping = true; }
            completion.notify_all();
            worker.join();
        }
        if (context.device && DeviceWaitIdle) DeviceWaitIdle(context.device);
        releaseBuffer(readback);
        if (readback.fence && DestroyFence) DestroyFence(context.device, readback.fence, nullptr);
        if (readback.pool && DestroyCommandPool) DestroyCommandPool(context.device, readback.pool, nullptr);
        if (negotiated && negotiation.destroy_device) negotiation.destroy_device();
        if (context.device && destroyDevice) destroyDevice(context.device, nullptr);
        if (instance && destroyInstance) destroyInstance(instance, nullptr);
        if (library) dlclose(library);
    }
    void releaseBuffer(Readback& slot) {
        if (slot.mapped && UnmapMemory) UnmapMemory(context.device, slot.memory);
        if (slot.buffer && DestroyBuffer) DestroyBuffer(context.device, slot.buffer, nullptr);
        if (slot.memory && FreeMemory) FreeMemory(context.device, slot.memory, nullptr);
        slot.mapped = nullptr; slot.buffer = VK_NULL_HANDLE; slot.memory = VK_NULL_HANDLE; slot.capacity = 0;
    }
    void wait(Readback& slot) {
        if (frameHandler) {
            std::unique_lock<std::mutex> lock(completionMutex);
            completion.wait(lock, [&] { return !slot.pending || workerError; });
            if (workerError) std::rethrow_exception(workerError);
            return;
        }
        if (!slot.pending) return;
        check(WaitForFences(context.device, 1, &slot.fence, VK_TRUE, 5'000'000'000ull), "Wait for GPU frame");
        slot.pending = false;
    }
    void finishFrames() {
        wait(readback);
    }
    Frame completed(Readback& slot) {
        check(WaitForFences(context.device, 1, &slot.fence, VK_TRUE, 5'000'000'000ull), "Wait for GPU frame");
        if (!slot.coherent) {
            VkMappedMemoryRange range{VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE};
            range.memory = slot.memory; range.size = VK_WHOLE_SIZE;
            check(InvalidateMappedMemoryRanges(context.device, 1, &range), "Read GPU memory");
        }
        return {static_cast<const uint8_t*>(slot.mapped), slot.bgra};
    }
    void deliverFrames() {
#if defined(__APPLE__)
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
#endif
        for (;;) {
            {
                std::unique_lock<std::mutex> lock(completionMutex);
                completion.wait(lock, [&] { return stopping || readback.pending; });
                if (!readback.pending) return;
            }
            auto& slot = readback;
            try {
                frameHandler(completed(slot), slot.width, slot.height);
            } catch (...) {
                { std::lock_guard<std::mutex> lock(completionMutex); workerError = std::current_exception(); }
                completion.notify_all();
                return;
            }
            { std::lock_guard<std::mutex> lock(completionMutex); slot.pending = false; }
            completion.notify_all();
        }
    }
    void allocateBuffer(Readback& slot, VkDeviceSize size) {
        if (slot.capacity >= size) return;
        releaseBuffer(slot);
        VkBufferCreateInfo info{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
        info.size = size; info.usage = VK_BUFFER_USAGE_TRANSFER_DST_BIT;
        info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
        check(CreateBuffer(context.device, &info, nullptr, &slot.buffer), "Create readback buffer");
        VkMemoryRequirements requirements{};
        GetBufferMemoryRequirements(context.device, slot.buffer, &requirements);
        VkPhysicalDeviceMemoryProperties properties{};
        proc<PFN_vkGetPhysicalDeviceMemoryProperties>("vkGetPhysicalDeviceMemoryProperties")(context.gpu, &properties);
        uint32_t selected = UINT32_MAX;
        for (uint32_t i = 0; i < properties.memoryTypeCount; ++i) {
            auto flags = properties.memoryTypes[i].propertyFlags;
            if ((requirements.memoryTypeBits & (1u << i)) && (flags & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT)) {
                selected = i;
                if (flags & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) break;
            }
        }
        if (selected == UINT32_MAX) throw std::runtime_error("The GPU has no CPU-readable memory");
        slot.coherent = properties.memoryTypes[selected].propertyFlags & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
        VkMemoryAllocateInfo allocation{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
        allocation.allocationSize = requirements.size; allocation.memoryTypeIndex = selected;
        check(AllocateMemory(context.device, &allocation, nullptr, &slot.memory), "Allocate readback memory");
        check(BindBufferMemory(context.device, slot.buffer, slot.memory, 0), "Bind readback memory");
        check(MapMemory(context.device, slot.memory, 0, VK_WHOLE_SIZE, 0, &slot.mapped), "Map readback memory");
        slot.capacity = size;
    }
    void initialize() {
        if (!hw.context_reset || !negotiation.create_device)
            throw std::runtime_error("The core did not negotiate Vulkan rendering");
        library = dlopen(libraryPath.c_str(), RTLD_NOW | RTLD_LOCAL);
        if (!library) throw std::runtime_error(std::string("Could not load MoltenVK: ") + dlerror());
        getInstanceProc = reinterpret_cast<PFN_vkGetInstanceProcAddr>(dlsym(library, "vkGetInstanceProcAddr"));
        if (!getInstanceProc) throw std::runtime_error("MoltenVK is missing vkGetInstanceProcAddr");
        auto enumerateExtensions = proc<PFN_vkEnumerateInstanceExtensionProperties>("vkEnumerateInstanceExtensionProperties");
        uint32_t count = 0;
        check(enumerateExtensions(nullptr, &count, nullptr), "Enumerate instance extensions");
        std::vector<VkExtensionProperties> available(count);
        check(enumerateExtensions(nullptr, &count, available.data()), "Read instance extensions");
        std::vector<const char*> extensions;
        for (const char* extension : {"VK_KHR_surface", "VK_KHR_get_physical_device_properties2", "VK_KHR_portability_enumeration"}) {
            if (std::any_of(available.begin(), available.end(), [extension](const auto& e) { return !strcmp(e.extensionName, extension); }))
                extensions.push_back(extension);
        }
        VkApplicationInfo defaultApp{VK_STRUCTURE_TYPE_APPLICATION_INFO};
        defaultApp.pApplicationName = "EmuDen"; defaultApp.apiVersion = VK_API_VERSION_1_1;
        auto app = negotiation.get_application_info ? negotiation.get_application_info() : nullptr;
        VkInstanceCreateInfo info{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO};
        info.pApplicationInfo = app ? app : &defaultApp;
        info.enabledExtensionCount = static_cast<uint32_t>(extensions.size());
        info.ppEnabledExtensionNames = extensions.data();
        if (std::find_if(extensions.begin(), extensions.end(), [](const char* e) { return !strcmp(e, "VK_KHR_portability_enumeration"); }) != extensions.end())
            info.flags |= VK_INSTANCE_CREATE_ENUMERATE_PORTABILITY_BIT_KHR;
        check(proc<PFN_vkCreateInstance>("vkCreateInstance")(&info, nullptr, &instance), "Create Vulkan instance");
        destroyInstance = proc<PFN_vkDestroyInstance>("vkDestroyInstance");
        auto enumerateDevices = proc<PFN_vkEnumeratePhysicalDevices>("vkEnumeratePhysicalDevices");
        count = 0; check(enumerateDevices(instance, &count, nullptr), "Enumerate GPUs");
        if (!count) throw std::runtime_error("MoltenVK did not find a Metal GPU");
        std::vector<VkPhysicalDevice> devices(count);
        check(enumerateDevices(instance, &count, devices.data()), "Read GPUs");
        VkPhysicalDeviceFeatures required{};
        if (!negotiation.create_device(&context, instance, devices.front(), VK_NULL_HANDLE,
                                      getInstanceProc, nullptr, 0, nullptr, 0, &required))
            throw std::runtime_error("Azahar could not create a Vulkan device");
        negotiated = true;
        getDeviceProc = proc<PFN_vkGetDeviceProcAddr>("vkGetDeviceProcAddr");
#if TARGET_OS_SIMULATOR
        if (const char* validation = getenv("EMUDEN_VALIDATE_GPU"); validation && !strcmp(validation, "1")) {
            diagnosticDeviceProc = getDeviceProc;
            diagnosticInstanceProc = getInstanceProc;
            diagnosticImageBarriers = 0;
            diagnosticPipelineBarrier = reinterpret_cast<PFN_vkCmdPipelineBarrier>(getDeviceProc(context.device, "vkCmdPipelineBarrier"));
            if (!diagnosticPipelineBarrier) throw std::runtime_error("GPU barrier validation unavailable");
            getDeviceProc = checkedDeviceProc;
        }
#endif
        destroyDevice = deviceProc<PFN_vkDestroyDevice>("vkDestroyDevice");
#define LOAD(name) name = deviceProc<PFN_vk##name>("vk" #name);
        DEVICE_FUNCTIONS(LOAD)
#undef LOAD
        VkPhysicalDeviceProperties properties{};
        proc<PFN_vkGetPhysicalDeviceProperties>("vkGetPhysicalDeviceProperties")(context.gpu, &properties);
        name = properties.deviceName;
        interface.interface_type = RETRO_HW_RENDER_INTERFACE_VULKAN;
        interface.interface_version = RETRO_HW_RENDER_INTERFACE_VULKAN_VERSION;
        interface.handle = this; interface.instance = instance; interface.gpu = context.gpu;
        interface.device = context.device; interface.queue = context.queue;
        interface.queue_index = context.queue_family_index;
        interface.get_device_proc_addr = getDeviceProc; interface.get_instance_proc_addr = getInstanceProc;
#if TARGET_OS_SIMULATOR
        if (getDeviceProc == checkedDeviceProc) interface.get_instance_proc_addr = checkedInstanceProc;
#endif
        interface.set_image = [](void* h, const retro_vulkan_image* image, uint32_t count, const VkSemaphore* semaphores, uint32_t family) {
            auto& p = *static_cast<Impl*>(h);
            p.hasImage = image != nullptr;
            if (image) p.image = *image;
            p.sourceQueue = family; p.waits.clear();
            if (count) p.waits.assign(semaphores, semaphores + count);
        };
        // The core exports one shared image; finish consuming it before the next presentation.
        interface.get_sync_index = [](void*) -> uint32_t { return 0; };
        interface.get_sync_index_mask = [](void*) -> uint32_t { return 1; };
        interface.wait_sync_index = [](void* h) { auto& p = *static_cast<Impl*>(h); p.wait(p.readback); };
        interface.lock_queue = [](void* h) { static_cast<Impl*>(h)->queueMutex.lock(); };
        interface.unlock_queue = [](void* h) { static_cast<Impl*>(h)->queueMutex.unlock(); };
        interface.set_command_buffers = [](void* h, uint32_t count, const VkCommandBuffer* commands) {
            auto& list = static_cast<Impl*>(h)->coreCommands; list.clear();
            if (count) list.assign(commands, commands + count);
        };
        interface.set_signal_semaphore = [](void* h, VkSemaphore s) { static_cast<Impl*>(h)->signal = s; };
        VkCommandPoolCreateInfo poolInfo{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO};
        poolInfo.queueFamilyIndex = context.queue_family_index;
        {
            auto& slot = readback;
            check(CreateCommandPool(context.device, &poolInfo, nullptr, &slot.pool), "Create readback command pool");
            VkCommandBufferAllocateInfo commandInfo{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
            commandInfo.commandPool = slot.pool; commandInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY; commandInfo.commandBufferCount = 1;
            check(AllocateCommandBuffers(context.device, &commandInfo, &slot.command), "Allocate readback commands");
            VkFenceCreateInfo fenceInfo{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
            check(CreateFence(context.device, &fenceInfo, nullptr, &slot.fence), "Create readback fence");
        }
        if (frameHandler) worker = std::thread([this] { deliverFrames(); });
        contextLive = true;
        hw.context_reset();
    }
    void submit(unsigned width, unsigned height) {
        if (!hasImage || !width || !height || width > 4096 || height > 4096)
            throw std::runtime_error("The core submitted an invalid GPU frame");
        if (sourceQueue != VK_QUEUE_FAMILY_IGNORED && sourceQueue != context.queue_family_index)
            throw std::runtime_error("The core submitted a frame from an unsupported GPU queue");
        const auto format = image.create_info.format;
        bool rgba = format == VK_FORMAT_R8G8B8A8_UNORM || format == VK_FORMAT_R8G8B8A8_SRGB;
        bool bgra = format == VK_FORMAT_B8G8R8A8_UNORM || format == VK_FORMAT_B8G8R8A8_SRGB;
        if (!rgba && !bgra) throw std::runtime_error("The core submitted an unsupported GPU pixel format");
        auto& slot = readback;
        wait(slot);
        const size_t size = size_t(width) * height * 4;
        allocateBuffer(slot, size);
        const auto command = slot.command;
        check(ResetCommandPool(context.device, slot.pool, 0), "Reset readback commands");
        VkCommandBufferBeginInfo begin{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
        begin.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
        check(BeginCommandBuffer(command, &begin), "Begin readback commands");
        const VkImageLayout copyLayout = image.image_layout == VK_IMAGE_LAYOUT_GENERAL ? VK_IMAGE_LAYOUT_GENERAL : VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL;
        VkImageMemoryBarrier barrier{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
        barrier.srcAccessMask = VK_ACCESS_MEMORY_WRITE_BIT; barrier.dstAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        barrier.oldLayout = image.image_layout; barrier.newLayout = copyLayout;
        barrier.srcQueueFamilyIndex = barrier.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        barrier.image = image.create_info.image;
        barrier.subresourceRange = image.create_info.subresourceRange;
        barrier.subresourceRange.levelCount = barrier.subresourceRange.layerCount = 1;
        CmdPipelineBarrier(command, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT, 0, 0, nullptr, 0, nullptr, 1, &barrier);
        VkBufferImageCopy copy{};
        copy.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, barrier.subresourceRange.baseMipLevel, barrier.subresourceRange.baseArrayLayer, 1};
        copy.imageExtent = {width, height, 1};
        CmdCopyImageToBuffer(command, barrier.image, copyLayout, slot.buffer, 1, &copy);
        barrier.srcAccessMask = VK_ACCESS_TRANSFER_READ_BIT;
        barrier.dstAccessMask = VK_ACCESS_MEMORY_READ_BIT | VK_ACCESS_MEMORY_WRITE_BIT;
        barrier.oldLayout = copyLayout; barrier.newLayout = image.image_layout;
        VkBufferMemoryBarrier host{VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER};
        host.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT; host.dstAccessMask = VK_ACCESS_HOST_READ_BIT;
        host.srcQueueFamilyIndex = host.dstQueueFamilyIndex = VK_QUEUE_FAMILY_IGNORED;
        host.buffer = slot.buffer; host.size = VK_WHOLE_SIZE;
        CmdPipelineBarrier(command, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_ALL_COMMANDS_BIT | VK_PIPELINE_STAGE_HOST_BIT,
                           0, 0, nullptr, 1, &host, 1, &barrier);
        check(EndCommandBuffer(command), "End readback commands");
        auto commands = coreCommands; commands.push_back(command);
        std::vector<VkPipelineStageFlags> stages(waits.size(), VK_PIPELINE_STAGE_ALL_COMMANDS_BIT);
        VkSubmitInfo submit{VK_STRUCTURE_TYPE_SUBMIT_INFO};
        submit.commandBufferCount = static_cast<uint32_t>(commands.size()); submit.pCommandBuffers = commands.data();
        if (coreCommands.empty()) {
            submit.waitSemaphoreCount = static_cast<uint32_t>(waits.size());
            submit.pWaitSemaphores = waits.data(); submit.pWaitDstStageMask = stages.data();
        }
        submit.signalSemaphoreCount = signal ? 1 : 0; submit.pSignalSemaphores = &signal;
        check(ResetFences(context.device, 1, &slot.fence), "Reset readback fence");
        {
            std::lock_guard<std::mutex> lock(queueMutex);
            check(QueueSubmit(context.queue, 1, &submit, slot.fence), "Submit readback commands");
        }
        slot.width = width; slot.height = height; slot.bgra = bgra;
        { std::lock_guard<std::mutex> lock(completionMutex); slot.pending = true; }
        waits.clear(); coreCommands.clear(); signal = VK_NULL_HANDLE;
    }
    VulkanVideo::Frame read(unsigned width, unsigned height) {
        submit(width, height);
        auto& slot = readback;
        const auto frame = completed(slot);
        slot.pending = false;
        return frame;
    }
    bool enqueue(unsigned width, unsigned height) {
        if (!frameHandler) return false;
        submit(width, height);
        completion.notify_all();
        return true;
    }
};

VulkanVideo::VulkanVideo(std::string path, FrameHandler handler) : p(std::make_unique<Impl>(std::move(path), std::move(handler))) {}
VulkanVideo::~VulkanVideo() = default;
bool VulkanVideo::requested() const { return p->hw.context_type == RETRO_HW_CONTEXT_VULKAN; }
void VulkanVideo::initialize() { p->initialize(); }
void VulkanVideo::destroyContext() {
    if (p->contextLive) {
        try { p->finishFrames(); } catch (...) { /* The transfer error was reported; still release the core's context. */ }
        p->contextLive = false;
        if (p->hw.context_destroy) p->hw.context_destroy();
    }
}
VulkanVideo::Frame VulkanVideo::readFrame(unsigned w, unsigned h) { return p->read(w, h); }
bool VulkanVideo::enqueueFrame(unsigned w, unsigned h) { return p->enqueue(w, h); }
void VulkanVideo::finishFrames() { p->finishFrames(); }
const std::string& VulkanVideo::deviceName() const { return p->name; }
bool VulkanVideo::environment(unsigned command, void* data) {
    if (!data) return false;
    switch (command) {
        case RETRO_ENVIRONMENT_GET_PREFERRED_HW_RENDER:
            *static_cast<unsigned*>(data) = RETRO_HW_CONTEXT_VULKAN; return true;
        case RETRO_ENVIRONMENT_GET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_SUPPORT: {
            auto* info = static_cast<retro_hw_render_context_negotiation_interface*>(data);
            info->interface_version = info->interface_type == RETRO_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_VULKAN ? 1 : 0;
            return true;
        }
        case RETRO_ENVIRONMENT_SET_HW_RENDER: {
            auto* callback = static_cast<retro_hw_render_callback*>(data);
            if (callback->context_type != RETRO_HW_CONTEXT_VULKAN) return false;
            p->hw = *callback; return true;
        }
        case RETRO_ENVIRONMENT_SET_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE: {
            auto* info = static_cast<retro_hw_render_context_negotiation_interface_vulkan*>(data);
            if (info->interface_type != RETRO_HW_RENDER_CONTEXT_NEGOTIATION_INTERFACE_VULKAN || info->interface_version < 1) return false;
            // v1 fields only: newer cores may supply a larger struct.
            p->negotiation.get_application_info = info->get_application_info;
            p->negotiation.create_device = info->create_device;
            p->negotiation.destroy_device = info->destroy_device;
            return true;
        }
        case RETRO_ENVIRONMENT_GET_HW_RENDER_INTERFACE:
            if (!p->context.device) return false;
            *static_cast<const retro_hw_render_interface**>(data) = reinterpret_cast<const retro_hw_render_interface*>(&p->interface);
            return true;
        default: return false;
    }
}
