#include "../Scripts/fixed-shader-stack.h"
#include <boost/circular_buffer.hpp>
#include <chrono>
#include <cstdio>
#include <memory>
#include <random>

static std::size_t allocations = 0;
template <typename T> struct CountAllocator : std::allocator<T> {
    template <typename U> struct rebind { using other = CountAllocator<U>; };
    T* allocate(std::size_t n) { ++allocations; return std::allocator<T>::allocate(n); }
};
template <std::size_t N> void compare() {
    boost::circular_buffer<int> reference(N);
    Pica::Shader::FixedShaderStack<int,N> actual;
    std::mt19937 random(20261108);
    for (int i=0;i<200000;++i) {
        if (reference.empty() || random()%4 != 0) { reference.push_back(i); actual.push_back(i); }
        else { reference.pop_back(); actual.pop_back(); }
        assert(reference.size() == actual.size() && reference.empty() == actual.empty());
        if (!reference.empty()) {
            assert(reference.back() == actual.back());
            reference.back() ^= 17; actual.back() ^= 17;
        }
    }
}
int main() {
    compare<4>(); compare<8>();
    volatile int sink = 0;
    constexpr int runs = 100000;
    auto start = std::chrono::steady_clock::now();
    for (int i=0;i<runs;++i) {
        boost::circular_buffer<int, CountAllocator<int>> a(8), b(4), c(4);
        a.push_back(i); b.push_back(i+1); c.push_back(i+2);
        sink = sink ^ a.back() ^ b.back() ^ c.back();
    }
    const auto old_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-start).count();
    assert(allocations == runs * 3);
    allocations = 0;
    start = std::chrono::steady_clock::now();
    for (int i=0;i<runs;++i) {
        Pica::Shader::FixedShaderStack<int,8> a;
        Pica::Shader::FixedShaderStack<int,4> b, c;
        a.push_back(i); b.push_back(i+1); c.push_back(i+2);
        sink = sink ^ a.back() ^ b.back() ^ c.back();
    }
    const auto new_ns = std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-start).count();
    assert(allocations == 0);
    printf("400000 reference operations matched; per %d shader calls: 300000 heap allocations removed. Stack-only microbenchmark %.2f -> %.2f ns/call (not game FPS).\n",runs,double(old_ns)/runs,double(new_ns)/runs);
}
