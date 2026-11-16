#pragma once
#include <algorithm>
#include <atomic>
#include <cstdint>

// Limits frontend delivery only; emulation, audio and GPU synchronization keep running.
class FrameDeliveryGate {
    std::atomic<uint64_t> next{0};
public:
    void reset() { next.store(0); }
    bool accept(uint64_t now, unsigned rate) {
        if (!rate) return true;
        const uint64_t interval = 1000000000ULL / std::clamp(rate, 1U, 240U);
        auto deadline = next.load();
        for (;;) {
            if (deadline && now + 500000 < deadline) return false;
            const auto base = !deadline || now > deadline + interval ? now : deadline;
            if (next.compare_exchange_weak(deadline, base + interval)) return true;
        }
    }
};
