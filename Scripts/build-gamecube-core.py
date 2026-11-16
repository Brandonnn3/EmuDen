#!/usr/bin/env python3
"""Build the pinned interpreter-only GameCube framework from a fresh source build."""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Vendor/Dolphin/Source'
PIN = 'f84df02055ab9610feec48e65648cac5a3c098fa'


def verify_source():
    manifest = json.loads((ROOT/'Vendor/Dolphin/source-manifest.json').read_text())
    archive = ROOT/'Upstream'/manifest['archive']
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == manifest['archiveSHA256']
    assert manifest['upstreamRevision'] == PIN
    has_git = (SOURCE/'.git').exists()
    if not SOURCE.exists():
        SOURCE.mkdir(parents=True)
        with tarfile.open(archive) as package:
            for member in package:
                relative = Path(member.name).relative_to('DolphinSource')
                assert member.isfile() and '..' not in relative.parts and '.git' not in relative.parts
                path = SOURCE/relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(package.extractfile(member).read())
                path.chmod(member.mode & 0o777)
    for name, digest in manifest['localPatches'].items():
        assert hashlib.sha256((ROOT/'Scripts'/name).read_bytes()).hexdigest() == digest, name
    subprocess.run([sys.executable,str(ROOT/'Scripts/sanitize-dolphin-source.py'),'--source',str(SOURCE),'--check'],check=True)
    assert hashlib.sha256((SOURCE/'EMUDEN-SOURCE.json').read_bytes()).hexdigest() == manifest['sourcePolicySHA256']
    if not has_git:
        expected = set()
        with tarfile.open(archive) as package:
            for member in package:
                relative = Path(member.name).relative_to('DolphinSource')
                assert member.isfile() and '..' not in relative.parts and '.git' not in relative.parts
                expected.add(relative.as_posix())
                path = SOURCE/relative
                assert not path.is_symlink() and path.read_bytes() == package.extractfile(member).read(), relative
        actual = {p.relative_to(SOURCE).as_posix() for p in SOURCE.rglob('*') if p.is_file()}
        assert actual == expected, 'Extracted corresponding source differs from its verified archive'
        return manifest, False
    assert subprocess.check_output(['git', '-C', str(SOURCE), 'rev-parse', 'HEAD'], text=True).strip() == PIN
    expected = set()
    for name in ['dolphin-generic-memtools.patch', 'dolphin-ios-port.patch']:
        patch = ROOT / 'Scripts' / name
        subprocess.run(['git', '-C', str(SOURCE), 'apply', '--reverse', '--check', str(patch)], check=True)
        expected.update(line.split(' b/', 1)[1] for line in patch.read_text().splitlines() if line.startswith('diff --git '))
    changed = set(subprocess.check_output(['git', '-C', str(SOURCE), 'diff', '--name-only'], text=True).splitlines())
    policy = json.loads((SOURCE/'EMUDEN-SOURCE.json').read_text())
    expected.add('Source/Core/Core/IOS/IOSC.cpp')
    expected.update(x['path'] for x in policy['omittedResources'])
    assert changed == expected, 'Review and record all upstream source changes before rebuilding'
    for line in subprocess.check_output(['git', '-C', str(SOURCE), 'submodule', 'status'], text=True).splitlines():
        assert not line.startswith(('+', 'U')), 'An initialized submodule differs from its pin'
    return manifest, True


def build(target, output_root):
    manifest, has_git = verify_source()
    cmake = ROOT/'.tools/bin/cmake'
    ninja = ROOT/'.tools/bin/ninja'
    if not cmake.is_file(): cmake = Path(shutil.which('cmake') or '')
    if not ninja.is_file(): ninja = Path(shutil.which('ninja') or '')
    assert cmake.is_file() and ninja.is_file(), 'Install CMake and Ninja (versions recorded in Docs/BUILD-28.md)'
    folder = output_root / target
    assert not folder.exists(), 'Preserve previous clean-build evidence; choose a new build rather than overwrite it'
    folder.mkdir(parents=True, exist_ok=True)
    options = {
        'CMAKE_MAKE_PROGRAM': str(ninja), 'CMAKE_SYSTEM_NAME': 'iOS',
        'CMAKE_OSX_SYSROOT': 'iphonesimulator' if target == 'Simulator' else 'iphoneos',
        'CMAKE_OSX_ARCHITECTURES': 'arm64', 'CMAKE_OSX_DEPLOYMENT_TARGET': '18.0',
        'CMAKE_TRY_COMPILE_TARGET_TYPE': 'STATIC_LIBRARY', 'CMAKE_BUILD_TYPE': 'Release',
        'CMAKE_CXX_FLAGS_RELEASE': '-O2 -g -DNDEBUG', 'CMAKE_C_FLAGS_RELEASE': '-O2 -g -DNDEBUG',
        'CMAKE_PROJECT_dolphin-emu_INCLUDE': str(ROOT / 'Scripts/dolphin-frontend.cmake'),
        'ENABLE_GENERIC': 'ON', 'ENABLE_HEADLESS': 'ON',
    }
    for key in ['ENABLE_NOGUI', 'ENABLE_QT', 'ENABLE_TESTS', 'ENABLE_AUTOUPDATE',
                'ENABLE_ANALYTICS', 'ENABLE_CUBEB', 'ENABLE_SDL', 'ENABLE_VULKAN',
                'ENABLE_LLVM', 'ENABLE_CLI_TOOL', 'USE_DISCORD_PRESENCE',
                'USE_RETRO_ACHIEVEMENTS', 'USE_MGBA', 'USE_UPNP',
                'USE_BUNDLED_MOLTENVK', 'ENCODE_FRAMEDUMPS', 'MACOS_CODE_SIGNING']:
        options[key] = 'OFF'
    if not has_git:
        options.update(CMAKE_DISABLE_FIND_PACKAGE_Git='TRUE', DOLPHIN_WC_REVISION=PIN,
                       DOLPHIN_WC_DESCRIBE='2609-emuden', DOLPHIN_WC_BRANCH='emuden-ios')
    log = folder / 'core-build.log'
    with log.open('wb') as stream:
        subprocess.run([str(cmake), '-S', str(SOURCE), '-B', str(folder), '-G', 'Ninja'] +
                       [f'-D{k}={v}' for k, v in options.items()], check=True, stdout=stream, stderr=subprocess.STDOUT)
        command = [str(cmake), '--build', str(folder), '--target', 'EmuDenGameCube', '--parallel', '2']
        if shutil.which('caffeinate'):
            command = ['caffeinate', '-i'] + command
        subprocess.run(command, check=True, stdout=stream, stderr=subprocess.STDOUT)
    framework = folder / 'EmuDenGameCube.framework'
    destination = ROOT / 'Vendor/Dolphin' / target / framework.name
    assert not destination.exists(), 'Never overwrite a recorded core binary'
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(framework,destination,symlinks=True)
    binary = destination / 'EmuDenGameCube'
    subprocess.run([sys.executable,str(ROOT/'Scripts/check-framework-metadata.py'),str(destination)],check=True)
    subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(destination)],check=True)
    subprocess.run(['xcrun','dsymutil',str(binary),'-o',str(destination)+'.dSYM'],check=True)
    subprocess.run([sys.executable,str(ROOT/'Scripts/check-debug-symbols.py'),str(binary),str(destination)+'.dSYM'],check=True)
    undefined=subprocess.check_output(['nm','-u',str(binary)],text=True)
    assert not any(n in undefined for n in ['_ptrace','_task_set_exception_ports'])
    record={'upstream':PIN,'target':target,'options':options,'fullCleanDistributionBuild':True,
            'frameworkSHA256':hashlib.sha256(binary.read_bytes()).hexdigest(),
            'sourcePatchSHA256':{n:hashlib.sha256((ROOT/'Scripts'/n).read_bytes()).hexdigest() for n in ['dolphin-generic-memtools.patch','dolphin-ios-port.patch']},
            'frontendSources':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'Bridge/GameCubeCore.cpp',ROOT/'Bridge/GameCubeCore.h',ROOT/'Bridge/GameCubeHost.cpp',ROOT/'Scripts/prepare-dolphin-audio.py']},
            'submodules':manifest['submodules'],
            'resourcePolicySHA256':hashlib.sha256((SOURCE/'EMUDEN-SOURCE.json').read_bytes()).hexdigest(),
            'distributionSigned':False,'log':str(log.relative_to(ROOT))}
    (folder/'build.json').write_text(json.dumps(record,indent=2)+'\n')
    print(f'{target} clean interpreter framework and genuine symbols built: {destination}')



if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=['Device', 'Simulator', 'all'], default='all')
    parser.add_argument('--output-root', type=Path, default=ROOT/'build/Build28-Core-Sanitized')
    parser.add_argument('--verify-source', action='store_true')
    args = parser.parse_args()
    if args.verify_source:
        verify_source()
        print('Pinned portable Dolphin source/dependencies and local changes verified')
        raise SystemExit(0)
    for target in (['Device', 'Simulator'] if args.target == 'all' else [args.target]):
        build(target, args.output_root.resolve())
