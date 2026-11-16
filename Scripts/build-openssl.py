#!/usr/bin/env python3
"""Build the pinned Apache-2.0 TLS replacement; never signs or publishes an app."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
VERSION = '3.5.9'
SHA256 = '603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a'
URL = f'https://github.com/openssl/openssl/releases/download/openssl-{VERSION}/openssl-{VERSION}.tar.gz'


def build(target):
    archive = ROOT / f'Upstream/openssl-{VERSION}.tar.gz'
    archive.parent.mkdir(exist_ok=True)
    if not archive.exists():
        request = urllib.request.Request(URL, headers={'User-Agent': 'EmuDenSourceBuild/22'})
        with urllib.request.urlopen(request, timeout=60) as response, archive.open('xb') as output:
            while block := response.read(1024 * 1024):
                output.write(block)
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == SHA256, 'OpenSSL source checksum mismatch'
    source = ROOT / 'Vendor/OpenSSL/Source'
    source.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive) as package:
        members = package.getmembers()
        prefix = f'openssl-{VERSION}/'
        assert all(m.name == prefix[:-1] or (m.name.startswith(prefix) and '..' not in Path(m.name).parts) for m in members)
        assert not any(m.issym() or m.islnk() for m in members), 'Review source links before extracting'
        if not (source / 'Configure').exists():
            for member in members:
                relative = member.name.removeprefix(prefix)
                if not relative or relative == prefix[:-1]:
                    continue
                member.name = relative
                package.extract(member, source)
        for member in members:
            if member.isfile():
                relative = member.name.removeprefix(prefix)
                expected = package.extractfile(member).read()
                assert (source / relative).read_bytes() == expected, f'Unrecorded OpenSSL source change: {relative}'
    folder = ROOT / 'build/OpenSSL' / target
    prefix = ROOT / 'Vendor/OpenSSL' / target
    folder.mkdir(parents=True, exist_ok=True)
    configuration = 'ios64-xcrun' if target == 'Device' else 'iossimulator-arm64-xcrun'
    sdk = 'iphoneos' if target == 'Device' else 'iphonesimulator'
    environment = os.environ.copy()
    environment['SDKROOT'] = subprocess.check_output(['xcrun', '--sdk', sdk, '--show-sdk-path'], text=True).strip()
    minimum = '-miphoneos-version-min=18.0' if target == 'Device' else '-mios-simulator-version-min=18.0'
    command = ['perl', str(source / 'Configure'), configuration, 'no-shared', 'no-module',
               'no-tests', 'no-apps', 'no-docs', '--libdir=lib', f'--prefix={prefix}', minimum]
    with (folder / 'build.log').open('wb') as log:
        for args in [command, ['make', '-j2'], ['make', 'install_sw']]:
            subprocess.run(args, cwd=folder, env=environment, stdout=log, stderr=subprocess.STDOUT, check=True)
    libraries = {}
    for name in ['libcrypto.a', 'libssl.a']:
        path = prefix / 'lib' / name
        assert path.is_file()
        assert subprocess.check_output(['xcrun', 'lipo', '-archs', str(path)], text=True).strip() == 'arm64'
        members = subprocess.check_output(['ar', '-t', str(path)], text=True).splitlines()
        member = next(name for name in members if name.endswith('.o'))
        sample = folder / (name + '.platform.o')
        sample.write_bytes(subprocess.check_output(['ar', '-p', str(path), member]))
        platform = subprocess.check_output(['xcrun', 'vtool', '-show-build', str(sample)], text=True)
        required = 'platform IOS\n' if target == 'Device' else 'platform IOSSIMULATOR\n'
        assert required in platform, 'Unexpected static library platform'
        libraries[name] = hashlib.sha256(path.read_bytes()).hexdigest()
    (folder / 'build.json').write_text(json.dumps({'version': VERSION, 'license': 'Apache-2.0',
        'sourceURL': URL, 'sourceSHA256': SHA256, 'target': target, 'configuration': command,
        'libraries': libraries, 'distributionApproved': False}, indent=2) + '\n')
    print(f'{target}: Apache-2.0 OpenSSL{VERSION} static libraries built and platform-checked')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=['Device', 'Simulator', 'all'], default='all')
    args = parser.parse_args()
    for target in (['Device', 'Simulator'] if args.target == 'all' else [args.target]):
        build(target)
