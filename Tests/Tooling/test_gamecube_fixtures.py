import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

def script(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT/'Scripts'/name)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

class GameCubeFixtureTests(unittest.TestCase):
    def test_gx_card_fixture_loads_exact_aligned_commands_in_mem1(self):
        module = script('make-gamecube-homebrew.py')
        data = module.make_dol(gx=True, card=True, full_input=True)
        offset, address, size = [struct.unpack_from('>I', data, n)[0] for n in (0x24, 0x6c, 0xb4)]
        commands = script('gamecube-gx-commands.py').commands()
        self.assertEqual(address, 0x80400000)
        self.assertEqual(offset % 32, 0)
        self.assertEqual(size % 32, 0)
        self.assertEqual(data[offset:offset+size], commands)
        self.assertEqual(offset+size, len(data))

    def test_factory_resource_redaction_requires_the_pinned_structure(self):
        module = script('sanitize-dolphin-source.py')
        arrays = []
        for i, name in enumerate(module.NAMES):
            values = ','.join(f'0x{(i*17+n)%256:02x}' for n in range([512,512,30,60][i]))
            arrays.append('constexpr Test '+name+' = {'+values+'};')
        vectors = '\n'.join('auto k'+str(i)+' = {{'+','.join(f'0x{(i*31+n)%256:02x}' for n in range(16))+'}};' for i in range(4))
        raw = ('\n'.join(arrays)+'\nconstexpr u32 DEFAULT_DEVICE_ID = 7;\nconstexpr u32 DEFAULT_KEY_ID = 8;\nvoid IOSC::LoadDefaultEntries()\n{\n'+vectors+'\n}').encode()
        clean, patterns = module.sanitized(raw)
        self.assertEqual(len(patterns), 8)
        self.assertEqual(clean.count(b'std::vector<u8>(AES128_KEY_SIZE)'), 4)
        self.assertNotIn(b'0x', clean)
        self.assertIn(b'DEFAULT_DEVICE_ID = 0;', clean)
        with self.assertRaises(AssertionError): module.sanitized(raw.replace(b'ROOT_PUBLIC_KEY =', b'CHANGED_NAME ='))

    def test_silent_fixture_stays_exact_and_tone_sections_are_aligned(self):
        module = script('make-gamecube-homebrew.py')
        self.assertEqual(module.make_dol(), (ROOT/'Tests/Fixtures/EmuDen-GC-Demo.dol').read_bytes())
        data = module.make_dol(audio=True)
        tone_offset = struct.unpack_from('>I', data, 0x20)[0]
        tone_size = struct.unpack_from('>I', data, 0xb0)[0]
        self.assertEqual(tone_offset % 32, 0)
        self.assertEqual(tone_size, 19200)
        self.assertEqual(len(data), tone_offset+tone_size)
        self.assertTrue(any(data[tone_offset:]))

    def test_audio_patch_refuses_changed_upstream_before_writing(self):
        module = script('prepare-dolphin-audio.py')
        with tempfile.TemporaryDirectory() as temp:
            source, output = Path(temp)/'source.cpp', Path(temp)/'output.cpp'
            source.write_text('different upstream revision')
            with self.assertRaises(AssertionError): module.prepare(source, output)
            self.assertFalse(output.exists())
