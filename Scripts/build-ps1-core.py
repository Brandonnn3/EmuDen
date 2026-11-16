#!/usr/bin/env python3
"""Build the pinned PCSX ReARMed interpreter; no JIT or proprietary firmware."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[1]
PIN = '7b0e8f8fadfbce3d170d195b9d9eecaabfa08c8e'
SOURCE = ROOT / 'Vendor/PCSX-ReARMed/Source'

def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)

def build(target):
    sdk, triple, platform = {
        'Simulator': ('iphonesimulator', 'arm64-apple-ios18.0-simulator', 'iPhoneSimulator'),
        'Device': ('iphoneos', 'arm64-apple-ios18.0', 'iPhoneOS'),
        'Host': ('macosx', 'arm64-apple-macos13.0', 'MacOSX'),
    }[target]
    manifest = json.loads((SOURCE.parent / 'source-manifest.json').read_text())
    assert manifest['revision'] == PIN
    if not SOURCE.is_dir():
        archive = next((p for p in [ROOT / 'build/Downloads' / manifest['archive'], ROOT / 'Upstream' / manifest['archive']] if p.is_file()), None)
        assert archive, 'Restore the pinned source archive described in PROVENANCE.md'
        assert hashlib.sha256(archive.read_bytes()).hexdigest() == manifest['archiveSHA256']
        with tarfile.open(archive) as tar:
            for item in tar.getmembers():
                assert not item.name.startswith('/') and '..' not in Path(item.name).parts
                assert (item.name == 'Source' and item.isdir()) or (item.name.startswith('Source/') and (item.isdir() or item.isfile()))
                assert not item.mode & 0o7000
            # Every member is a regular file/directory beneath Source; support Xcode's Python 3.9 too.
            tar.extractall(SOURCE.parent)
    work = ROOT / 'build/PCSX-ReARMed' / target
    if work.exists(): shutil.rmtree(work)
    for relative, expected in manifest['files'].items():
        source = SOURCE / relative
        assert source.is_file() and not source.is_symlink() and hashlib.sha256(source.read_bytes()).hexdigest() == expected, relative
        destination = work / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    # Upstream's ptrace trick is solely for JIT. Never compile it into this interpreter.
    p = work / 'frontend/libretro.c'
    text = p.read_text()
    guard = '#if defined(__MACH__) && !defined(TVOS)'
    assert text.count(guard) == 1
    p.write_text(text.replace(guard, guard + ' && !defined(DRC_DISABLE)'))
    sdkpath = subprocess.check_output(['xcrun', '--sdk', sdk, '--show-sdk-path'], text=True).strip()
    compiler = subprocess.check_output(['xcrun', '--sdk', sdk, '--find', 'clang'], text=True).strip()
    cc = f'{compiler} -target {triple} -isysroot {sdkpath}'
    args = ['make', '-f', 'Makefile.libretro', '-j6',
            'platform=osx' if target == 'Host' else 'platform=ios-arm64',
            'DYNAREC=0', 'BUILTIN_GPU=neon', 'HAVE_NEON_ASM=0', 'MINVERSION=',
            'HAVE_PHYSICAL_CDROM=0', 'USE_ASYNC_SPU=0', 'CC=' + cc,
            'CXX=' + cc.replace('/clang ', '/clang++ '), 'CFLAGS_OPT=-O3 -g']
    run(*args, cwd=work)
    output = SOURCE.parent / target
    framework = output / 'PCSXReARMed.framework'
    framework.mkdir(parents=True, exist_ok=True)
    binary = framework / 'PCSXReARMed'
    shutil.copy2(work / ('pcsx_rearmed_libretro.dylib' if target == 'Host' else 'pcsx_rearmed_libretro_ios.dylib'), binary)
    run('install_name_tool', '-id', '@rpath/PCSXReARMed.framework/PCSXReARMed', str(binary))
    metadata = {'CFBundleExecutable': 'PCSXReARMed', 'CFBundleIdentifier': 'org.libretro.pcsx-rearmed.emuden',
                'CFBundleName': 'PCSXReARMed', 'CFBundlePackageType': 'FMWK',
                'CFBundleShortVersionString': '1.0', 'CFBundleVersion': '1',
                'CFBundleSupportedPlatforms': [platform], 'MinimumOSVersion': '13.0' if target == 'Host' else '18.0'}
    (framework / 'Info.plist').write_bytes(plistlib.dumps(metadata))
    symbols = output / 'PCSXReARMed.framework.dSYM'
    if symbols.exists(): shutil.rmtree(symbols)
    run('dsymutil', str(binary), '-o', str(symbols))
    undefined = subprocess.check_output(['nm', '-u', str(binary)], text=True)
    assert '_syscall' not in undefined and '_ptrace' not in undefined
    assert '_mprotect' not in undefined, 'Review unexpected executable-memory support'
    run('codesign', '--force', '--sign', '-', '--timestamp=none', str(framework))
    (output / 'build.json').write_text(json.dumps({'revision': PIN, 'target': triple, 'dynarec': False,
        'gpu': 'NEON software renderer', 'ptraceCompiled': False, 'physicalCDROM': False,
        'sha256': hashlib.sha256(binary.read_bytes()).hexdigest()}, indent=2) + '\n')

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--target', choices=['Simulator', 'Device', 'Host', 'all'], default='all')
    a = p.parse_args()
    for t in (['Host', 'Simulator', 'Device'] if a.target == 'all' else [a.target]): build(t)
