#include "../Bridge/InputLatch.h"
#include <cassert>
int main() {
    InputLatch input;
    input.setButton(8, true); input.setButton(8, false); input.poll();
    assert(input.buttons() == 1u << 8);
    input.poll(); assert(input.buttons() == 0);
    input.setButton(0, true); input.poll(); input.poll(); assert(input.buttons() == 1);
    input.setTouch(123, 456, true); input.setTouch(0, 0, false); input.poll();
    assert(input.touch().down && input.touch().x == 123 && input.touch().y == 456);
    input.poll(); assert(!input.touch().down && input.touch().x == 123);
    input.setButton(5, true); input.setTouch(12, 34, true); input.clear(); input.poll();
    assert(input.buttons() == 0 && !input.touch().down);
}
