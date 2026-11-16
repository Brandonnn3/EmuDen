#!/usr/bin/env python3
"""Require framework metadata to agree with the actual compiled iOS deployment target."""
import argparse
from pathlib import Path
import plistlib
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def version(value):
    assert isinstance(value,str) and re.fullmatch(r'\d+(?:\.\d+){0,2}',value), f'Invalid or missing version: {value!r}'
    return tuple((list(map(int,value.split('.')))+[0,0])[:3])


def binary_target(binary):
    output = subprocess.check_output(['xcrun','vtool','-show-build',str(binary)],text=True)
    platforms=re.findall(r'platform\s+(\w+)',output);minimums=re.findall(r'minos\s+([\d.]+)',output)
    assert len(platforms)==len(minimums)==1 and platforms[0] in ('IOS','IOSSIMULATOR'), binary
    return platforms[0],minimums[0]


def check_info(info, platform, minimum, app_minimum=None):
    for key in ['CFBundleExecutable','CFBundleIdentifier','CFBundleName']:
        assert isinstance(info.get(key),str) and info[key].strip(), f'Missing {key}'
    assert info.get('CFBundlePackageType')=='FMWK'
    version(info.get('CFBundleVersion'));version(info.get('CFBundleShortVersionString'))
    assert version(info.get('MinimumOSVersion'))==version(minimum), 'Framework MinimumOSVersion must match Mach-O minos'
    assert version(minimum)>=(8,0,0), '64-bit iOS framework requires iOS8 or later'
    if app_minimum is not None:assert version(minimum)<=version(app_minimum), 'Framework requires a newer OS than the app supports'
    expected=['iPhoneOS' if platform=='IOS' else 'iPhoneSimulator']
    if info.get('CFBundleSupportedPlatforms') is not None or info['CFBundleExecutable']=='EmuDenGameCube':
        assert info.get('CFBundleSupportedPlatforms')==expected, 'Wrong framework platform'


def check(folder, platform=None, app_minimum=None):
    info=plistlib.loads((folder/'Info.plist').read_bytes())
    actual,minimum=binary_target(folder/info['CFBundleExecutable'])
    if platform:assert actual==platform, 'Device/Simulator framework mismatch'
    check_info(info,actual,minimum,app_minimum)
    print(f'Verified {folder.name}: {actual}, MinimumOSVersion {minimum}, nonempty bundle versions/name')


def prepare_gamecube(folder):
    assert folder.name=='EmuDenGameCube.framework' and not folder.is_symlink(), 'Prepare an isolated GameCube framework copy only'
    platform,minimum=binary_target(folder/'EmuDenGameCube')
    text=(ROOT/'Scripts/GameCubeFramework-Info.plist.in').read_text()
    text=text.replace('@EMUDEN_GC_PLATFORM@','iPhoneOS' if platform=='IOS' else 'iPhoneSimulator').replace('@CMAKE_OSX_DEPLOYMENT_TARGET@',minimum)
    info=plistlib.loads(text.encode());check_info(info,platform,minimum)
    (folder/'Info.plist').write_bytes(text.encode())


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('framework',type=Path);parser.add_argument('--prepare-gamecube',action='store_true')
    parser.add_argument('--platform',choices=['IOS','IOSSIMULATOR']);parser.add_argument('--app-minimum')
    args=parser.parse_args()
    if args.prepare_gamecube:prepare_gamecube(args.framework)
    check(args.framework,args.platform,args.app_minimum)
