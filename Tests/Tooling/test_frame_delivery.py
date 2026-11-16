import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class FrameDeliveryTests(unittest.TestCase):
    def test_delivery_rate_jitter_stalls_and_concurrent_callbacks(self):
        source = r'''
#include "FrameDelivery.h"
#include <cassert>
#include <thread>
#include <vector>
int main() {
    for (unsigned source : {50U, 60U, 120U}) {
        FrameDeliveryGate images, nativeUI;
        unsigned count = 0, ui = 0;
        for (unsigned n=0;n<source*10;++n) {
            const auto t=1000000000ULL+n*1000000000ULL/source;
            count += images.accept(t,30); ui += nativeUI.accept(t,10);
        }
        assert(count>=299 && count<=301); assert(ui>=99 && ui<=101);
    }
    FrameDeliveryGate gate;
    assert(gate.accept(1000000000,30)); assert(!gate.accept(1000000001,30));
    assert(gate.accept(20000000000ULL,30)); assert(!gate.accept(20000000001ULL,30));
    gate.reset(); assert(gate.accept(1000000001,30));
    for (unsigned n=0;n<100;++n) assert(gate.accept(n,0));
    gate.reset(); std::atomic<unsigned> accepted{0}; std::vector<std::thread> workers;
    for(unsigned n=0;n<16;++n) workers.emplace_back([&]{accepted += gate.accept(5000000000ULL,30);});
    for(auto& thread:workers) thread.join(); assert(accepted==1);
}
'''
        with tempfile.TemporaryDirectory() as tmp:
            code = Path(tmp) / "frame.cpp"
            binary = Path(tmp) / "frame"
            code.write_text(source)
            subprocess.run(["clang++", "-std=c++17", "-O2", "-pthread", "-I", str(ROOT / "Bridge"), str(code), "-o", str(binary)], check=True)
            subprocess.run([str(binary)], check=True)
