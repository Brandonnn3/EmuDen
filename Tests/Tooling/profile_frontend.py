#!/usr/bin/env python3
"""Profile bundled original homebrew in an explicitly selected owned EmuDen QA Simulator."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
BUNDLE = 'com.brandonaleman.Emulator'

def sim(*args, check=True):
    return subprocess.run(['xcrun', 'simctl', *args], check=check, capture_output=True, text=True).stdout.strip()

def run(device, stage, presentation, samples=12):
    devices = json.loads(sim('list', 'devices', '--json'))['devices']
    selected = [d for rows in devices.values() for d in rows if d['udid'] == device]
    assert len(selected) == 1 and selected[0]['name'].startswith('EmuDen ') and selected[0]['name'].endswith(' QA') and selected[0]['state'] == 'Booted', 'Use an explicitly owned, booted EmuDen QA Simulator'
    target = ROOT/'build/Build36'/stage
    target.mkdir(parents=True, exist_ok=False)
    inputs = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for folder in ['App','Bridge'] for p in sorted((ROOT/folder).rglob('*')) if p.is_file() and p.name != '.DS_Store'}
    app = Path(sim('get_app_container', device, BUNDLE, 'app'))
    metadata = {'scope':'Debug arm64, bundled original homebrew in owned Duo Simulator. Frame delivery/copy overhead only; not phone speed, battery or retail-game evidence.', 'device':selected[0], 'presentation':presentation, 'sourceInputs':inputs, 'executableSHA256':hashlib.sha256((app/'EmuDen').read_bytes()).hexdigest()}
    (target/'inputs.json').write_text(json.dumps(metadata,indent=2)+'\n')
    try:
        for platform, flag in [('ps1','--boot-ps1-demo'),('3ds','--boot-homebrew'),('gamecube','--boot-gamecube-demo')]:
            sim('terminate',device,BUNDLE,check=False)
            root=Path(sim('get_app_container',device,BUNDLE,'data'))
            file=root/'tmp'/('frontend-'+platform+'.json')
            file.unlink(missing_ok=True)
            sim('launch',device,BUNDLE,flag,'--fresh-start','--profile-frontend','-framePresentation',presentation,'-onlineArtworkEnabled','NO','-automaticResumeSaves','NO','-menuSoundsEnabled','NO')
            rows=[]; deadline=time.monotonic()+75
            while time.monotonic()<deadline:
                time.sleep(1)
                try: rows=json.loads(file.read_text())
                except (OSError,ValueError): continue
                if len(rows)>=samples: break
            assert len(rows)>=samples, (platform, len(rows))
            assert all('uiUpdatesTotal' in r and r['resolution']==1 for r in rows), 'Use native-resolution original fixtures'
            (target/(platform+'.json')).write_text(json.dumps(rows,indent=2)+'\n')
            frames=rows[-1]['sourceFramesTotal']-rows[0]['sourceFramesTotal']
            updates=rows[-1]['uiUpdatesTotal']-rows[0]['uiUpdatesTotal']
            print(f'{stage} {platform}: {frames} source frames, {updates} UI deliveries, ratio {updates/frames:.3f}',flush=True)
    finally: sim('terminate',device,BUNDLE,check=False)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device',required=True);parser.add_argument('--stage',required=True,choices=['final-full','final-reduced'])
    parser.add_argument('--presentation',required=True,choices=['full','reduced'])
    args=parser.parse_args();run(args.device,args.stage,args.presentation)
