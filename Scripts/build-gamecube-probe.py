#!/usr/bin/env python3
"""Build the isolated original-homebrew probe; never installs or publishes it."""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Vendor/Dolphin/Source'
PIN = 'f84df02055ab9610feec48e65648cac5a3c098fa'


def build(target):
    cmake = ROOT / '.tools/bin/cmake'
    ninja = ROOT / '.tools/bin/ninja'
    assert cmake.is_file() and ninja.is_file(), 'Install the recorded CMake/Ninja tools first'
    assert subprocess.check_output(['git', '-C', str(SOURCE), 'rev-parse', 'HEAD'], text=True).strip() == PIN
    expected = set()
    for name in ['dolphin-generic-memtools.patch', 'dolphin-ios-port.patch']:
        patch = ROOT / 'Scripts' / name
        subprocess.run(['git', '-C', str(SOURCE), 'apply', '--reverse', '--check', str(patch)], check=True)
        expected.update(line.split(' b/', 1)[1] for line in patch.read_text().splitlines() if line.startswith('diff --git '))
    changed = set(subprocess.check_output(['git', '-C', str(SOURCE), 'diff', '--name-only'], text=True).splitlines())
    assert changed == expected, 'Review and record all upstream source changes before rebuilding'
    for line in subprocess.check_output(['git', '-C', str(SOURCE), 'submodule', 'status'], text=True).splitlines():
        assert not line.startswith(('+', 'U')), 'An initialized submodule differs from its pin'
    folder = ROOT / 'build/Dolphin-Feasibility' / target
    folder.mkdir(parents=True, exist_ok=True)
    options = {
        'CMAKE_MAKE_PROGRAM': str(ninja), 'CMAKE_SYSTEM_NAME': 'iOS',
        'CMAKE_OSX_SYSROOT': 'iphonesimulator' if target == 'Simulator' else 'iphoneos',
        'CMAKE_OSX_ARCHITECTURES': 'arm64', 'CMAKE_OSX_DEPLOYMENT_TARGET': '18.0',
        'CMAKE_TRY_COMPILE_TARGET_TYPE': 'STATIC_LIBRARY', 'CMAKE_BUILD_TYPE': 'Release',
        'CMAKE_PROJECT_dolphin-emu_INCLUDE': str(ROOT / 'Scripts/dolphin-frontend.cmake'),
        'ENABLE_GENERIC': 'ON', 'ENABLE_HEADLESS': 'ON',
    }
    for key in ['ENABLE_NOGUI', 'ENABLE_QT', 'ENABLE_TESTS', 'ENABLE_AUTOUPDATE',
                'ENABLE_ANALYTICS', 'ENABLE_CUBEB', 'ENABLE_SDL', 'ENABLE_VULKAN',
                'ENABLE_LLVM', 'ENABLE_CLI_TOOL', 'USE_DISCORD_PRESENCE',
                'USE_RETRO_ACHIEVEMENTS', 'USE_MGBA', 'USE_UPNP',
                'USE_BUNDLED_MOLTENVK', 'ENCODE_FRAMEDUMPS', 'MACOS_CODE_SIGNING']:
        options[key] = 'OFF'
    log = folder / 'emuden-probe-build.log'
    with log.open('wb') as stream:
        subprocess.run([str(cmake), '-S', str(SOURCE), '-B', str(folder), '-G', 'Ninja'] +
                       [f'-D{k}={v}' for k, v in options.items()], check=True, stdout=stream, stderr=subprocess.STDOUT)
        command = [str(cmake), '--build', str(folder), '--target', 'EmuDenGameCubeProbe', '--parallel', '2']
        if shutil.which('caffeinate'):
            command = ['caffeinate', '-i'] + command
        subprocess.run(command, check=True, stdout=stream, stderr=subprocess.STDOUT)
    app = folder / 'Binaries/EmuDenGameCubeProbe.app'
    subprocess.run([sys.executable, str(ROOT/'Scripts/make-gamecube-homebrew.py'), '--output', str(app/'EmuDen-GC-Demo.dol')], check=True)
    if target == 'Simulator':
        for item in [app/'Frameworks/EmuDenGameCube.framework', app]:
            subprocess.run(['codesign', '--force', '--sign', '-', str(item)], check=True)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    binary = app / 'Frameworks/EmuDenGameCube.framework/EmuDenGameCube'
    record = {'upstream': PIN, 'target': target, 'options': options,
              'frameworkSHA256': hashlib.sha256(binary.read_bytes()).hexdigest(),
              'originalDOLSHA256': hashlib.sha256((app/'EmuDen-GC-Demo.dol').read_bytes()).hexdigest(),
              'distributionSigned': False, 'log': str(log.relative_to(ROOT))}
    (folder/'emuden-probe-build.json').write_text(json.dumps(record, indent=2)+'\n')
    print(f'{target} development probe built: {app}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=['Device', 'Simulator', 'all'], default='all')
    args = parser.parse_args()
    for target in (['Device', 'Simulator'] if args.target == 'all' else [args.target]):
        build(target)
