#!/usr/bin/env python3
"""Exercise a real linked ELF, corrupt metadata and instruction compatibility."""
import importlib.util
import os
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('elf_to_hex', ROOT/'scripts/elf_to_hex.py')
loader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(loader)
ELF = Path(os.environ['CF04_TEST_ELF'])
GOLDEN = ['04000113','02800293','010000ef','00513023',
          '00013503','0000006f','00228293','00008067']


class ElfTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = ELF.read_bytes()
        cls.phoff = struct.unpack_from('<Q', cls.data, 32)[0]
        cls.shoff = struct.unpack_from('<Q', cls.data, 40)[0]
        cls.payload = struct.unpack_from('<Q', cls.data, cls.phoff+8)[0]
        n = struct.unpack_from('<H', cls.data, 60)[0]
        cls.text_section = next(cls.shoff+i*64 for i in range(n)
                                if struct.unpack_from('<Q', cls.data, cls.shoff+i*64+8)[0]&2)

    def change(self, offset, fmt, value):
        data = bytearray(self.data)
        struct.pack_into(fmt, data, offset, value)
        return bytes(data)

    def test_real_elf_golden_words(self):
        text, report = loader.convert(self.data)
        self.assertEqual(text.split(), GOLDEN)
        self.assertEqual(report['entry'], 0x80000000)
        self.assertEqual(report['byte_count'], 32)

    def test_partial_header_and_bad_ident(self):
        for data in [b'', self.data[:63], b'BAD!'+self.data[4:],
                     self.change(4,'B',1), self.change(5,'B',2), self.change(6,'B',0)]:
            with self.subTest(length=len(data)):
                with self.assertRaises(loader.ImageError): loader.convert(data)

    def test_header_rejections(self):
        cases=[(16,'H',1),(18,'H',62),(20,'I',0),(24,'Q',0x80000004),
               (48,'I',1),(48,'I',4),(48,'I',8),(52,'H',63),(54,'H',55),
               (56,'H',0),(56,'H',65535),(32,'Q',len(self.data)),
               (58,'H',0),(60,'H',0),(62,'H',0),(40,'Q',len(self.data))]
        for off,fmt,value in cases:
            with self.subTest(offset=off,value=value):
                with self.assertRaises(loader.ImageError): loader.convert(self.change(off,fmt,value))

    def test_bad_rom_configuration(self):
        for base,words in [(0x80000002,1024),(-4,1024),(2**64,1),
                           (0x80000000,0),(0x80000000,-1),(2**64-4,2),
                           (0x80000000,7)]:
            with self.subTest(base=base,words=words):
                with self.assertRaises(loader.ImageError): loader.convert(self.data,base,words)

    def test_segment_rejections(self):
        p=self.phoff
        cases=[(p,'I',0),(p,'I',2),(p,'I',3),(p,'I',7),
               (p+4,'I',4),(p+4,'I',7),(p+24,'Q',0),
               (p+32,'Q',0),(p+32,'Q',31),(p+40,'Q',40),
               (p+8,'Q',len(self.data)),(p+16,'Q',0x7ffffffc),
               (p+16,'Q',0x80001000),(p+48,'Q',3)]
        for off,fmt,value in cases:
            with self.subTest(offset=off,value=value):
                with self.assertRaises(loader.ImageError): loader.convert(self.change(off,fmt,value))

    def test_segment_range_and_word_size(self):
        for address in [0x7ffffffc,0x80001000,0x80000ffc]:
            data=bytearray(self.data)
            struct.pack_into('<Q',data,self.phoff+16,address)
            struct.pack_into('<Q',data,self.phoff+24,address)
            with self.subTest(address=hex(address)):
                with self.assertRaisesRegex(loader.ImageError,'outside ROM'):
                    loader.convert(bytes(data))
        data=bytearray(self.data)
        struct.pack_into('<Q',data,self.phoff+32,31)
        struct.pack_into('<Q',data,self.phoff+40,31)
        with self.assertRaisesRegex(loader.ImageError,'alignment'):
            loader.convert(bytes(data))

    def test_linker_rejects_unsupported_sections_and_oversize(self):
        source=(ROOT/'software/baremetal/cf04-smoke/start.S').read_text()
        variants=[('data',source+'\n.section .data\n.quad 42\n','startup is not implemented'),
                  ('oversize','.section .text.start,"ax",@progbits\n.global _start\n_start:\n.rept 1025\naddi x0,x0,0\n.endr\n','text exceeds instruction ROM')]
        with tempfile.TemporaryDirectory(prefix='link-contract.') as directory:
            root=Path(directory)
            for name,text,marker in variants:
                with self.subTest(variant=name):
                    asm=root/(name+'.S');obj=root/(name+'.o');out=root/(name+'.elf')
                    asm.write_text(text)
                    subprocess.run([os.environ['RISCV_AS'],'-march=rv64i','-mabi=lp64','-mno-relax','-o',str(obj),str(asm)],check=True,capture_output=True)
                    result=subprocess.run([os.environ['RISCV_LD'],'--no-relax','-T',str(ROOT/'software/baremetal/cf04-smoke/link.ld'),'-o',str(out),str(obj)],capture_output=True,text=True)
                    self.assertNotEqual(result.returncode,0)
                    self.assertIn(marker,result.stderr)

    def test_overlapping_segments(self):
        data=bytearray(self.data)
        struct.pack_into('<H',data,56,2)
        data[self.phoff+56:self.phoff+112]=data[self.phoff:self.phoff+56]
        with self.assertRaisesRegex(loader.ImageError,'overlapping'): loader.convert(data)

    def test_allocated_section_rejections(self):
        s=self.text_section
        for off,fmt,value in [(s+4,'I',8),(s+8,'Q',3),(s+8,'Q',2),
                              (s+16,'Q',0),(s+24,'Q',len(self.data)),
                              (s+32,'Q',3),(s,'I',0xffffffff)]:
            with self.subTest(offset=off,value=value):
                with self.assertRaises(loader.ImageError): loader.convert(self.change(off,fmt,value))

    def test_upper_instructions_accepted(self):
        for word in [0x000002b7,0x800002b7,0xfffff017,0x80000297]:
            with self.subTest(word=hex(word)):
                loader.convert(self.change(self.payload,'I',word))

    def test_unsupported_instructions(self):
        # ADDIW, MUL, compressed halfwords, LW, ECALL and malformed JALR.
        for word in [0x0012829b,0x025282b3,
                     0x00010001,0x00012503,0x00000073,0x00009067,0xffffffff]:
            with self.subTest(word=hex(word)):
                with self.assertRaisesRegex(loader.ImageError,'unsupported instruction'):
                    loader.convert(self.change(self.payload,'I',word))

    def test_unlinked_object_rejected(self):
        with self.assertRaises(loader.ImageError): loader.convert(ELF.with_suffix('.o').read_bytes())

    def test_cli_preserves_input_and_output_on_error(self):
        with tempfile.TemporaryDirectory(prefix='elf-cli.') as directory:
            root=Path(directory);bad=root/'bad.elf';out=root/'out.hex'
            bad.write_bytes(b'bad');out.write_text('keep')
            r=subprocess.run([sys.executable,str(ROOT/'scripts/elf_to_hex.py'),str(bad),str(out)],capture_output=True,text=True)
            self.assertNotEqual(r.returncode,0)
            self.assertIn('ELF_IMAGE_ERROR',r.stderr)
            self.assertEqual(out.read_text(),'keep')
            self.assertEqual(bad.read_bytes(),b'bad')
            for alias in [root/'hardlink',root/'symlink']:
                if alias.name=='hardlink':os.link(ELF,alias)
                else:alias.symlink_to(ELF)
                r=subprocess.run([sys.executable,str(ROOT/'scripts/elf_to_hex.py'),str(ELF),str(alias)],capture_output=True,text=True)
                self.assertNotEqual(r.returncode,0)
                self.assertEqual(alias.read_bytes(),self.data)

    def test_sparse_segments_use_nop_padding(self):
        # Canonical synthetic ELF with two instructions at base and base+12.
        data=bytearray(0x400)
        data[:64]=struct.pack('<16sHHIQQQIHHHHHH',b'\x7fELF\x02\x01\x01'+bytes(9),
                             2,243,1,0x80000000,64,0x300,0,64,56,2,64,4,3)
        for i,(addr,off,word) in enumerate([(0x80000000,0x100,0x00500093),
                                          (0x8000000c,0x104,0x00700113)]):
            struct.pack_into('<IIQQQQQQ',data,64+i*56,1,5,off,addr,addr,4,4,4)
            struct.pack_into('<I',data,off,word)
            struct.pack_into('<IIQQQQIIQQ',data,0x300+(i+1)*64,1,1,6,addr,off,4,0,0,4,0)
        names=b'\0.text\0.names\0';data[0x200:0x200+len(names)]=names
        struct.pack_into('<IIQQQQIIQQ',data,0x300+3*64,7,3,0,0,0x200,len(names),0,0,1,0)
        text,report=loader.convert(bytes(data))
        self.assertEqual(text.split(),['00500093','00000013','00000013','00700113'])
        self.assertEqual(report['load_segments'],2)


if __name__=='__main__':
    unittest.main(verbosity=2)
