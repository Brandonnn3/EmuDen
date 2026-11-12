#!/usr/bin/env python3
"""Small, repeatable fixes for the pinned Azahar 2127.0-rc1 libretro host."""
from pathlib import Path
import subprocess
import os

root = Path(__file__).resolve().parent.parent / "Vendor/Azahar/Source"
patch_environment = {**os.environ, "GIT_CEILING_DIRECTORIES": str(root.parent)}
patches = [
    ("src/citra_libretro/citra_libretro.cpp",
     "CitraLibRetro() : log_filter(Common::Log::Level::Debug) {}",
     "CitraLibRetro() : log_filter(Common::Log::Level::Info) {}"),
    ("src/video_core/renderer_vulkan/renderer_vulkan.cpp",
     "        scheduler.Flush(frame->render_ready);\n        window.Present(frame);",
     "        scheduler.Flush(frame->render_ready);\n"
     "#ifdef HAVE_LIBRETRO\n"
     "        // The frontend must see this submission before reading the output image.\n"
     "        scheduler.WaitWorker();\n"
     "#endif\n"
     "        window.Present(frame);"),
    ("src/citra_libretro/citra_libretro.cpp",
     "            LibRetro::DisplayMessage(msg.c_str());\n        }\n    }",
     "            LibRetro::DisplayMessage(msg.c_str());\n"
     "            // Return control so the frontend can show the error and stop cleanly.\n"
     "            break;\n        }\n    }"),
    ("src/citra_libretro/libretro_vk.cpp",
     "    // wait_thread will be automatically stopped by jthread destructor\n"
     "    // Clean up remaining fences\n"
     "    const vk::Device device{instance.GetDevice()};\n"
     "    for (const auto& fence : free_queue) {\n"
     "        device.destroyFence(fence);\n    }",
     "    // Stop the worker before destroying fences it can still access.\n"
     "    wait_thread.request_stop();\n"
     "    wait_cv.notify_all();\n"
     "    if (wait_thread.joinable()) wait_thread.join();\n"
     "    const vk::Device device{instance.GetDevice()};\n"
     "    device.waitIdle();\n"
     "    for (const auto& fence : free_queue) {\n"
     "        device.destroyFence(fence);\n    }\n"
     "    while (!wait_queue.empty()) {\n"
     "        device.destroyFence(wait_queue.front().first);\n"
     "        wait_queue.pop();\n    }"),
]
for name, old, new in patches:
    path = root / name
    source = path.read_text()
    if new in source:
        continue
    expected = 1
    if source.count(old) != expected:
        raise SystemExit(f"Unexpected source in {name}; refusing an ambiguous patch")
    path.write_text(source.replace(old, new))
    print(f"Patched {name}")

for name in ["azahar-simulator-buffers.patch", "azahar-moltenvk-features.patch", "azahar-save-state-cache.patch", "azahar-shader-stacks.patch", "azahar-shader-stutter.patch", "azahar-async-pipeline-probe.patch", "azahar-player-settings.patch", "azahar-no-bundled-resources.patch"]:
    patch = Path(__file__).with_name(name)
    check = subprocess.run(["git", "apply", "--check", str(patch)], cwd=root, env=patch_environment, capture_output=True)
    if check.returncode == 0:
        subprocess.run(["git", "apply", str(patch)], cwd=root, env=patch_environment, check=True)
        print(f"Applied {name}")
    else:
        applied = subprocess.run(["git", "apply", "--reverse", "--check", str(patch)], cwd=root, env=patch_environment, capture_output=True)
        if applied.returncode:
            raise SystemExit(f"Unexpected source for {name}; refusing an ambiguous patch")

shader_stack = Path(__file__).with_name("fixed-shader-stack.h").read_text()
shader_destination = root / "src/video_core/shader/fixed_shader_stack.h"
if shader_destination.exists() and shader_destination.read_text() != shader_stack:
    raise SystemExit("Unexpected fixed shader stack; refusing to overwrite it")
if not shader_destination.exists():
    shader_destination.write_text(shader_stack)
