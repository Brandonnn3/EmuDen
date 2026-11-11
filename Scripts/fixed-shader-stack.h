// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once
#include <array>
#include <cassert>
#include <cstddef>
#include <type_traits>

namespace Pica::Shader {
// Match circular_buffer's overwrite-oldest behavior without allocating for every vertex.
template <typename T, std::size_t Capacity>
class FixedShaderStack {
    static_assert(Capacity > 0);
    static_assert(std::is_trivially_copyable_v<T>);
public:
    void push_back(const T& value) {
        if (count < Capacity) {
            data[(first + count) % Capacity] = value;
            ++count;
        } else {
            data[first] = value;
            first = (first + 1) % Capacity;
        }
    }
    T& back() { assert(count); return data[(first + count - 1) % Capacity]; }
    void pop_back() { assert(count); --count; }
    bool empty() const { return count == 0; }
    std::size_t size() const { return count; }
private:
    std::array<T, Capacity> data;
    std::size_t first = 0, count = 0;
};
}
