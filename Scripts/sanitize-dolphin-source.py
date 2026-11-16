#!/usr/bin/env python3
"""Remove unused Wii factory identities/keys and console-resource blobs for GC-only builds."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess
PIN='f84df02055ab9610feec48e65648cac5a3c098fa'
FILE='Source/Core/Core/IOS/IOSC.cpp'
NAMES=['ROOT_PUBLIC_KEY','ROOT_PUBLIC_KEY_DEV','DEFAULT_PRIVATE_KEY','DEFAULT_SIGNATURE']
def digest(raw):return hashlib.sha256(raw).hexdigest()
def sanitized(raw):
    text=raw.decode();patterns=[]
    for name in NAMES:
        pattern=r'(constexpr\s+[^;\n]+\s'+name+r'\s*=\s*)(.*?);'
        match=re.search(pattern,text,re.S);assert match,name
        values=re.findall(r'0x([0-9a-fA-F]{2})(?![0-9a-fA-F])',match[2])
        data=bytes(int(n,16) for n in values);assert len(data) in [30,60,512],(name,len(data))
        patterns.append((name,data));text=text[:match.start(2)]+'{}'+text[match.end(2):]
    start=text.index('void IOSC::LoadDefaultEntries()');end=text.index('\n}',start)+2
    body=text[start:end];index=0
    def remove(match):
        nonlocal index
        data=bytes(int(n,16) for n in re.findall(r'0x([0-9a-fA-F]{2})(?![0-9a-fA-F])',match[0]));assert len(data)==16
        patterns.append(('unused-Wii-AES-'+str(index),data));index+=1
        return 'std::vector<u8>(AES128_KEY_SIZE)'
    body=re.sub(r'\{\{[^{}]+\}\}',remove,body);assert index==4,index
    text=text[:start]+body+text[end:]
    for name in ['DEFAULT_DEVICE_ID','DEFAULT_KEY_ID']:
        text,count=re.subn(r'(constexpr u32 '+name+r'\s*=\s*)[^;]+;',r'\g<1>0;',text);assert count==1
    return text.encode(),patterns

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--check',action='store_true');p.add_argument('--audit-binary',type=Path);p.add_argument('--audit-output',type=Path);a=p.parse_args();root=a.source.resolve();policy=root/'EMUDEN-SOURCE.json'
    if a.check:
        d=json.loads(policy.read_text());assert d['upstream']==PIN
        assert digest((root/FILE).read_bytes())==d['sanitizedIOSCSHA256']
        assert all(not (root/x['path']).exists() for x in d['omittedResources'])
    else:
        raw=(root/FILE).read_bytes();clean,patterns=sanitized(raw)
        omitted=[]
        for f in [*(root/'Data/Sys/GC').glob('*.bin'),*(root/'Data/Sys/Wii').rglob('*')]:
            if f.is_file():omitted.append({'path':str(f.relative_to(root)),'sha256':digest(f.read_bytes()),'bytes':f.stat().st_size});f.unlink()
        (root/FILE).write_bytes(clean)
        d={'upstream':PIN,'scope':'GC-only; no bundled Wii factory keys/identity, GC DSP ROM/coefficients or console fonts/Wii resources','originalIOSCSHA256':digest(raw),'sanitizedIOSCSHA256':digest(clean),'omittedResources':omitted,'removedPatterns':[{'name':n,'bytes':len(b),'sha256':digest(b)} for n,b in patterns]}
        policy.write_text(json.dumps(d,indent=2)+'\n')
    if a.audit_binary:
        original=subprocess.check_output(['git','-C',str(root),'show','HEAD:'+FILE]);_,patterns=sanitized(original)
        binary=a.audit_binary.read_bytes();hits=[n for n,b in patterns if b in binary]
        resources=json.loads(policy.read_text())['omittedResources'];resource_hits=[]
        for entry in resources:
            blob=subprocess.check_output(['git','-C',str(root),'show','HEAD:'+entry['path']])
            assert digest(blob)==entry['sha256']
            if blob in binary:resource_hits.append(entry['path'])
        audit={'binarySHA256':digest(binary),'removedPatternCount':len(patterns),'matches':hits,
               'omittedResourceCount':len(resources),'omittedResourceMatches':resource_hits,'policySHA256':digest(policy.read_bytes())}
        if a.audit_output:a.audit_output.write_text(json.dumps(audit,indent=2)+'\n')
        assert not hits,'Bundled upstream key/identity bytes remain: '+','.join(hits)
        assert not resource_hits,'Bundled original system-resource payload remains: '+','.join(resource_hits)
    print('Dolphin GC-only source/resource policy verified')
if __name__=='__main__':main()
