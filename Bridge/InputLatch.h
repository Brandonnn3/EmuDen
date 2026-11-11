#pragma once
#include <cstdint>
#include <mutex>

// Retain a brief press until the next core poll, even when emulation is running slowly.
class InputLatch {
public:
    struct Touch { int16_t x = 0, y = 0; bool down = false; };
    void setButton(unsigned id, bool pressed) {
        if (id >= 16) return;
        std::lock_guard<std::mutex> lock(mutex);
        const unsigned mask = 1u << id;
        if (pressed && !(held & mask)) pending |= mask;
        if (pressed) held |= mask; else held &= ~mask;
    }
    void setTouch(int16_t x, int16_t y, bool pressed) {
        std::lock_guard<std::mutex> lock(mutex);
        if (pressed) {
            live = {x, y, true};
            if (!wasDown) { pendingTouch = live; touchPending = true; }
        } else live.down = false; // Keep the release at the last actual screen coordinate.
        wasDown = pressed;
    }
    void poll() {
        std::lock_guard<std::mutex> lock(mutex);
        sampledButtons = held | pending; pending = 0;
        sampledTouch = touchPending ? pendingTouch : live;
        touchPending = false;
    }
    unsigned buttons() { std::lock_guard<std::mutex> lock(mutex); return sampledButtons; }
    Touch touch() { std::lock_guard<std::mutex> lock(mutex); return sampledTouch; }
    void clear() {
        std::lock_guard<std::mutex> lock(mutex);
        held = pending = sampledButtons = 0;
        live = pendingTouch = sampledTouch = {};
        touchPending = wasDown = false;
    }
private:
    std::mutex mutex;
    unsigned held = 0, pending = 0, sampledButtons = 0;
    Touch live, pendingTouch, sampledTouch;
    bool touchPending = false, wasDown = false;
};
