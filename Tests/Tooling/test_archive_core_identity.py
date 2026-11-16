import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('archive_validation', ROOT/'Scripts/validate-testflight.py')
validation = importlib.util.module_from_spec(spec); spec.loader.exec_module(validation)


class CoreIdentityTests(unittest.TestCase):
    def test_signing_envelope_may_change_but_runtime_bytes_may_not(self):
        def binary(signature, code=b'original runtime code'):
            size = 32+72+16
            data = bytearray(struct.pack('<IiiIIIII',0xfeedfacf,0x100000c,0,6,2,88,0,0))
            data += struct.pack('<II16sQQQQiiII',0x19,72,b'__LINKEDIT',0x1000,len(code)+len(signature),size,len(code)+len(signature),1,1,0,0)
            data += struct.pack('<IIII',0x1d,16,size+len(code),len(signature))
            return data+code+signature
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'core'
            path.write_bytes(binary(b'adhoc'))
            expected = validation.signature_free_code_sha256(path)
            path.write_bytes(binary(b'longer Apple development signature'))
            self.assertEqual(validation.signature_free_code_sha256(path),expected)
            path.write_bytes(binary(b'longer Apple development signature',b'altered runtime code!'))
            self.assertNotEqual(validation.signature_free_code_sha256(path),expected)
            path.write_bytes(b'bad archive')
            with self.assertRaises(AssertionError): validation.signature_free_code_sha256(path)
