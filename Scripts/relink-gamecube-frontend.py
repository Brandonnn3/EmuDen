#!/usr/bin/env python3
"""Iterate the iOS frontend against checked, unchanged prototype core archives.

No cache/prototype input is modified. The normal CMake frontend includes the same
generated audio unit; a fresh full build remains required before distribution.
"""
import argparse
import hashlib
import importlib.util
import json
import shlex
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024*1024), b''): h.update(block)
    return h.hexdigest()

def build(cache, target):
    base = (cache/target).resolve()
    source = (ROOT/'Vendor/Dolphin/Source').resolve()
    assert subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'], text=True).strip() == 'f84df02055ab9610feec48e65648cac5a3c098fa'
    for name in ['dolphin-generic-memtools.patch','dolphin-ios-port.patch']:
        subprocess.run(['git','-C',str(source),'apply','--reverse','--check',str(ROOT/'Scripts'/name)], check=True)
    original = base/'EmuDenGameCube.framework/EmuDenGameCube'
    original_hash = digest(original)
    raw = subprocess.check_output([str(ROOT/'.tools/bin/ninja'),'-C',str(base),'-t','commands','EmuDenGameCube'], text=True)
    compile_lines = [line for line in raw.splitlines() if ' -c ' in line and 'GameCubeCore.cpp' in line]
    link_lines = [line for line in raw.splitlines() if ' -dynamiclib ' in line]
    assert len(compile_lines) == len(link_lines) == 1
    work = ROOT/'build/Build25-Core'/target; work.mkdir(parents=True, exist_ok=True)
    spec = importlib.util.spec_from_file_location('emuden_audio',ROOT/'Scripts/prepare-dolphin-audio.py')
    helper = importlib.util.module_from_spec(spec); spec.loader.exec_module(helper)
    generated = work/'EmuDenAudioCommon.cpp'
    helper.prepare(source/'Source/Core/AudioCommon/AudioCommon.cpp',generated)
    objects = []
    commands = []
    for cpp in [ROOT/'Bridge/GameCubeCore.cpp',ROOT/'Bridge/GameCubeHost.cpp',generated]:
        args = shlex.split(compile_lines[0]); out = work/(cpp.stem+'.o')
        for option,value in [('-c',str(cpp)),('-o',str(out)),('-MF',str(out)+'.d'),('-MT',str(out))]: args[args.index(option)+1]=value
        args += ['-g']
        subprocess.run(args,cwd=base,check=True); commands.append(args); objects.append(out)
    folder = ROOT/'Vendor/Dolphin'/target/'EmuDenGameCube.framework'
    if folder.exists(): shutil.rmtree(folder)
    shutil.copytree(base/'EmuDenGameCube.framework',folder,symlinks=True)
    (folder/'Headers').mkdir(exist_ok=True); shutil.copy2(ROOT/'Bridge/GameCubeCore.h',folder/'Headers/GameCubeCore.h')
    args = shlex.split(link_lines[0]); start = args.index('&&')+1; args = args[start:args.index('&&',start)]
    args[args.index('-o')+1] = str(folder/'EmuDenGameCube')
    for i,arg in enumerate(args):
        if arg.endswith('GameCubeCore.cpp.o'): args[i]=str(objects[0])
        if arg.endswith('GameCubeHost.cpp.o'): args[i]=str(objects[1])
    args.insert(args.index(str(objects[1]))+1,str(objects[2]))
    libraries = {str((base/p).resolve()):digest(base/p) for p in args if p.endswith('.a')}
    subprocess.run(args,cwd=base,check=True); commands.append(args)
    subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(folder)],check=True)
    subprocess.run(['xcrun','dsymutil',str(folder/'EmuDenGameCube'),'-o',str(folder)+'.dSYM'],check=True)
    undefined = subprocess.check_output(['nm','-u',str(folder/'EmuDenGameCube')],text=True)
    assert not any(symbol in undefined for symbol in ['_ptrace','_task_set_exception_ports'])
    # The pinned generic core uses public page protection for ordinary memory, not JIT.
    before = subprocess.check_output(['nm','-u',str(original)],text=True)
    for symbol in ['_mprotect','_vm_protect']:
        assert (symbol in undefined) == (symbol in before), 'Review a changed memory-protection dependency'
    assert digest(original) == original_hash, 'Preserve the prototype input'
    record = {'target':target,'prototypeSHA256':original_hash,'coreArchives':libraries,'commands':commands,
              'frontendSources':{str(p.relative_to(ROOT)):digest(p) for p in [ROOT/'Bridge/GameCubeCore.cpp',ROOT/'Bridge/GameCubeCore.h',ROOT/'Bridge/GameCubeHost.cpp',ROOT/'Scripts/prepare-dolphin-audio.py']},
              'frameworkSHA256':digest(folder/'EmuDenGameCube'),'fullCleanDistributionBuild':False}
    (work/'build.json').write_text(json.dumps(record,indent=2)+'\n')
    print(f'{target} frontend/PCM iteration linked; prototype preserved: {folder}')

if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--cache-root',type=Path,required=True)
    p.add_argument('--target',choices=['Simulator','Device','all'],default='all')
    args=p.parse_args()
    for target in (['Simulator','Device'] if args.target=='all' else [args.target]): build(args.cache_root,target)
