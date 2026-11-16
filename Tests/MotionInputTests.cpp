#include "MotionInput.h"
#include <cassert>
#include <limits>

int main() {
    MotionInput m;
    assert(!m.state(0, RETRO_SENSOR_GYROSCOPE_ENABLE));
    assert(m.read(0, 2) == -1 && m.read(0, 3) == 0);
    m.available(true, true); m.enable(true);
    assert(m.state(0, RETRO_SENSOR_ACCELEROMETER_ENABLE));
    assert(m.state(0, RETRO_SENSOR_GYROSCOPE_ENABLE));
    assert(m.requested() && m.active());
    assert(!m.state(1, RETRO_SENSOR_GYROSCOPE_ENABLE));
    assert(!m.state(0, RETRO_SENSOR_ILLUMINANCE_ENABLE));
    m.sample({0.25f, 0.5f, -0.75f, 0.1f, -0.2f, 0.3f});
    assert(m.read(0, 0) == 0.25f && m.read(0, 2) == -0.75f && m.read(0, 4) == -0.2f);
    assert(m.read(1, 0) == 0 && m.read(0, 6) == 0);
    m.state(0, RETRO_SENSOR_GYROSCOPE_DISABLE);
    assert(m.read(0, 3) == 0 && m.read(0, 0) == 0.25f);
    m.state(0, RETRO_SENSOR_GYROSCOPE_ENABLE);
    m.enable(false); m.sample({1, 1, 1, 1, 1, 1}); m.enable(true);
    assert(m.read(0, 2) == -1 && m.read(0, 5) == 0);
    m.sample({100, -100, 100, -100, 100, -100});
    assert(m.read(0, 0) == 16 && m.read(0, 1) == -16 && m.read(0, 3) == -32 && m.read(0, 4) == 32);
    m.sample({std::numeric_limits<float>::quiet_NaN(), 0, 0, 1, 1, 1});
    assert(m.read(0, 2) == -1 && m.read(0, 5) == 0);
    m.available(false, false);
    assert(!m.state(0, RETRO_SENSOR_GYROSCOPE_ENABLE));
}
