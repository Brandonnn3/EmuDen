#pragma once
#include <memory>
#include <string>
#include <cstdint>
#include <functional>

// Shared by the iOS host and the Mac integration test.
class VulkanVideo {
public:
    struct Frame { const uint8_t* data; bool bgra; };
    // Runs on the transfer worker; consume/copy pixels before returning.
    using FrameHandler = std::function<void(Frame, unsigned, unsigned)>;
    explicit VulkanVideo(std::string libraryPath, FrameHandler handler = {});
    ~VulkanVideo();
    VulkanVideo(const VulkanVideo&) = delete;
    VulkanVideo& operator=(const VulkanVideo&) = delete;
    bool environment(unsigned command, void* data);
    bool requested() const;
    void initialize();
    void destroyContext(); // Call after retro_unload_game, before retro_deinit.
    // The mapped pixels remain valid until the next read or context destruction.
    Frame readFrame(unsigned width, unsigned height);
    bool enqueueFrame(unsigned width, unsigned height); // False when no asynchronous handler is installed.
    void finishFrames(); // Drain GPU work before state changes or core teardown.
    const std::string& deviceName() const;
private:
    struct Impl;
    std::unique_ptr<Impl> p;
};
