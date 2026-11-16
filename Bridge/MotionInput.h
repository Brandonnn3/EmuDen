#pragma once
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include "libretro.h"

class MotionInput {
public:
    void available(bool acceleration, bool gyroscope) { accelerometer = acceleration; gyro = gyroscope; }
    void enable(bool value) {
        enabled = value;
        if (!value) neutral();
    }
    bool state(unsigned port, retro_sensor_action action) {
        if (port) return false;
        switch (action) {
        case RETRO_SENSOR_ACCELEROMETER_ENABLE: accelRequested = accelerometer.load(); return accelRequested;
        case RETRO_SENSOR_GYROSCOPE_ENABLE: gyroRequested = gyro.load(); return gyroRequested;
        case RETRO_SENSOR_ACCELEROMETER_DISABLE: accelRequested = false; return true;
        case RETRO_SENSOR_GYROSCOPE_DISABLE: gyroRequested = false; return true;
        default: return false;
        }
    }
    void sample(std::array<float, 6> values) {
        if (!enabled) return;
        for (float value : values) if (!std::isfinite(value)) { neutral(); return; }
        // Bound physical samples before the core's signed16-bit HID conversion.
        for (unsigned i = 0; i < 6; ++i) samples[i] = std::clamp(values[i], i < 3 ? -16.0f : -32.0f, i < 3 ? 16.0f : 32.0f);
    }
    float read(unsigned port, unsigned id) const {
        if (port || id >= 6) return 0;
        const bool ready = id < 3 ? accelerometer && accelRequested : gyro && gyroRequested;
        return enabled && ready ? samples[id].load() : (id == 2 ? -1.0f : 0.0f);
    }
    bool requested() const { return accelRequested && gyroRequested; }
    bool active() const { return enabled && accelerometer && gyro && requested(); }
private:
    void neutral() { for (unsigned i = 0; i < 6; ++i) samples[i] = i == 2 ? -1.0f : 0.0f; }
    std::atomic_bool accelerometer{false}, gyro{false}, enabled{false}, accelRequested{false}, gyroRequested{false};
    std::array<std::atomic<float>, 6> samples{{0, 0, -1, 0, 0, 0}};
};
