"""Original colored, depth-tested GX geometry; registers follow pinned Dolphin.

Draw a red near triangle before a larger blue far triangle, so a red center
also proves Z occlusion. No external textures, shaders, SDK or firmware.
"""
import struct

def commands():
    out = bytearray()
    def word(n): out.extend(struct.pack('>I', n))
    def bp(reg,n): out.append(0x61); word((reg<<24)|n)
    def cp(reg,n): out.extend((0x08,reg)); word(n)
    def xf(reg,values):
        out.append(0x10); word(((len(values)-1)<<16)|reg)
        for n in values: word(n if isinstance(n,int) else struct.unpack('>I',struct.pack('>f',n))[0])
    cp(0x50,0x2200); cp(0x60,0); cp(0x70,0x16009); cp(0x80,0); cp(0x90,0)
    xf(0,[1.,0.,0.,0.,0.,1.,0.,0.,0.,0.,1.,0.])
    xf(0x1008,[1,1]); xf(0x100e,[1]); xf(0x1010,[1]); xf(0x103f,[0])
    xf(0x1018,[0,0]); xf(0x101a,[160.,-120.,16777215.,502.,462.,16777215.])
    xf(0x1020,[1.,0.,1.,0.,-1./9.,-10./9.,1])
    for reg in [1,2,3,4]: bp(reg,0x666666)
    bp(0x44,3); bp(0x42,0)
    bp(0x00,0x10); bp(0x20,342|(342<<12)); bp(0x21,581|(661<<12)); bp(0x59,171|(171<<10))
    bp(0x40,0x17); bp(0x41,0x18); bp(0x43,0x40); bp(0xf3,(7<<16)|(7<<19))
    bp(0x28,0); bp(0xc0,0x8fffa); bp(0xc1,0x80000|(7<<13)|(7<<10)|(7<<7)|(5<<4))
    bp(0xf6,4); bp(0xf7,14)
    bp(0x49,0); bp(0x4a,319|(239<<10)); bp(0x4d,20); bp(0x4e,256); bp(0x4b,0x100000>>5)
    bp(0x53,(21<<12)|(22<<18)); bp(0x54,21)
    bp(0x4f,0xff10); bp(0x50,0x1018); bp(0x51,0xffffff)
    bp(0x52,0x4800) # Copy/clear once to establish the EFB background.
    for vertices,color in [([(-.65,-.6,-2.),(.65,-.6,-2.),(0.,.7,-2.)],0xff2020ff),
                           ([(-.9,-.8,-6.),(.9,-.8,-6.),(0.,.9,-6.)],0x2040ffff)]:
        out.append(0x90); out.extend(struct.pack('>H',3))
        for xyz in vertices: out.extend(struct.pack('>fffI',*xyz,color))
    bp(0x52,0x4000)
    bp(0x45,2) # Draw-done flushes the guest's GX work.
    out.extend(b'\0'*(-len(out)%32))
    return bytes(out)
