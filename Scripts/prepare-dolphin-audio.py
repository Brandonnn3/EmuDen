#!/usr/bin/env python3
"""Generate the pinned upstream audio backend unit with a local PCM factory.

The upstream checkout and its archived prototype remain unchanged. The generated
object precedes libaudiocommon.a, whose other mixer/backend objects are reused.
"""
import argparse
import hashlib
from pathlib import Path

PINNED_SHA = '45271beb47d9c66586c58447e047486041719404e02fe916dcb9de88c6e90877'

def prepare(source, output):
    data = source.read_bytes()
    assert hashlib.sha256(data).hexdigest() == PINNED_SHA, 'Review a changed upstream audio unit before applying the factory'
    text = data.decode()
    namespace = 'namespace AudioCommon\n{'
    branch = '  if (backend == BACKEND_CUBEB && CubebStream::IsValid())'
    assert text.count(namespace) == 1 and text.count(branch) == 1
    text = text.replace(namespace, 'extern SoundStream* EmuDenGC_CreateSoundStream();\n\n'+namespace)
    text = text.replace(branch, '  if (backend == "EmuDen PCM")\n    return std::unique_ptr<SoundStream>(EmuDenGC_CreateSoundStream());\n'+branch)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text)

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args(); prepare(args.source, args.output)
