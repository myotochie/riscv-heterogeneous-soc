#!/usr/bin/env python3
"""Verify the software inventory, its GAS oracle and explicit audit outcomes."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[3]
spec=importlib.util.spec_from_file_location('inventory',ROOT/'scripts/riscv_isa_inventory.py')
isa=importlib.util.module_from_spec(spec);spec.loader.exec_module(isa)
spec2=importlib.util.spec_from_file_location('inspection',ROOT/'scripts/inspect_c_toolchain.py')
# The inspection module imports its sibling by name.
import sys
sys.path.insert(0,str(ROOT/'scripts'))
inspection=importlib.util.module_from_spec(spec2);spec2.loader.exec_module(inspection)
REPORT=json.loads((Path(os.environ['CF05_INVENTORY_ROOT'])/'inventory.json').read_text())


class InventoryTests(unittest.TestCase):
    def test_gas_oracle_all_52_base_forms_and_guard(self):
        with tempfile.TemporaryDirectory(prefix='cf05-isa.') as directory:
            root=Path(directory);obj=root/'base.o';binary=root/'base.bin'
            subprocess.run([os.environ['RISCV_AS'],'-march=rv64i','-mabi=lp64','-mno-relax',
                            '-o',str(obj),str(ROOT/'verification/unit/cf05_inventory/isa_base.S')],check=True)
            subprocess.run([os.environ['RISCV_OBJCOPY'],'-O','binary','--only-section=.text',str(obj),str(binary)],check=True)
            data=binary.read_bytes();self.assertEqual(len(data),52*4)
            expected=[name for names in isa.BASE_GROUPS.values() for name in names.split()]
            for offset,name in enumerate(expected):
                word=int.from_bytes(data[offset*4:offset*4+4],'little')
                with self.subTest(instruction=name):
                    self.assertEqual(isa.decode(word),name)
                    self.assertEqual(isa._guard.instruction_supported(word),name in isa.SUPPORTED_BASE)

    def test_matrix_complete_and_evidence_files_exist(self):
        rows=isa.matrix()
        self.assertEqual(len(rows),52)
        self.assertEqual(sum(r['rtl_status']=='present' for r in rows),23)
        for row in rows:
            self.assertTrue((ROOT/row['rtl_source']).is_file())
            for source in row['test_sources']:self.assertTrue((ROOT/source).is_file())
        self.assertIn('not established',next(r for r in rows if r['instruction']=='SUB')['coverage_limit'])

    def test_disassembly_and_relocation_line(self):
        rows=isa.disassembly('''0000 <f>:
   0: 00000517 auipc a0,0
        0: R_RISCV_PCREL_HI20 symbol
   4: 00008067 jalr zero,0(ra)
''')
        self.assertEqual([r['instruction'] for r in rows],['AUIPC','JALR'])
        self.assertTrue(rows[0]['image_guard_accepts'])
        self.assertTrue(rows[1]['image_guard_accepts'])

    def test_rejects_compressed_or_empty_disassembly(self):
        for text in ['nothing','   0: 0001 c.nop']:
            with self.subTest(text=text):
                with self.assertRaises(ValueError):isa.disassembly(text)
        self.assertEqual(isa.decode(0xffffffff),'UNKNOWN')
        self.assertEqual(isa.decode(0x00009067),'UNKNOWN')

    def test_undefined_and_defined_symbol_parsing(self):
        defined,missing=inspection.symbols('''   0: 0000000000000000 0 NOTYPE LOCAL DEFAULT UND
   2: 0000000000000100 8 OBJECT GLOBAL DEFAULT 2 probe_data
   3: 0000000000000000 0 NOTYPE GLOBAL DEFAULT UND __muldi3
''')
        self.assertEqual(defined,{'probe_data':256})
        self.assertEqual(missing,['__muldi3'])

    def test_report_dimensions_and_no_unknown_machine_words(self):
        self.assertEqual(REPORT['object_configurations'],48)
        self.assertEqual(sum(REPORT['link_outcomes'].values()),144)
        for row in REPORT['results']:
            self.assertNotIn('UNKNOWN',row['object_instructions'])
            self.assertEqual([i['ram_base'] for i in row['layouts']],[0,256,2048])
            for item in row['layouts']:
                self.assertIn(item['status'],['linked_not_executed','unresolved_runtime_helpers','relocation_range_rejected'])
                if item['status']=='linked_not_executed':self.assertNotIn('UNKNOWN',item['instructions'])

    def test_runtime_and_relocation_errors_remain_reported(self):
        self.assertGreater(REPORT['link_outcomes'].get('unresolved_runtime_helpers',0),0)
        self.assertGreater(REPORT['link_outcomes'].get('relocation_range_rejected',0),0)
        for row in REPORT['results']:
            if row['probe']=='runtime_helpers':
                self.assertTrue(row['undefined_symbols'])
                self.assertTrue(all(item['status']=='unresolved_runtime_helpers' for item in row['layouts']))
        self.assertIn('no C program executed on RTL',REPORT['meaning'])

    def test_compiler_resolver_tool_identity_and_diagnostics(self):
        # Driver fixture tests path resolution only. The inventory separately
        # compiles and links with real GCC/Binutils.
        with tempfile.TemporaryDirectory(prefix='cf05-resolver.') as directory:
            root=Path(directory); (root/'alias').mkdir()
            for name in ['as','ld']:
                (root/('alias-'+name)).symlink_to(os.environ['RISCV_'+name.upper()])
            other=root/'other-as';other.write_text('#!/bin/sh\nexit 0\n');other.chmod(0o755)
            compiler=root/'gcc'
            compiler.write_text("""#!/bin/bash
case "${!#}" in
    -dumpmachine) printf '%s\n' "$TEST_TARGET" ;;
    -print-prog-name=as) printf '%s\n' "$TEST_AS" ;;
    -print-prog-name=ld) printf '%s\n' "$TEST_LD" ;;
    *) exit 2 ;;
esac
""")
            compiler.chmod(0o755)
            env={**os.environ,'RISCV_GCC':str(compiler),
                 'TEST_TARGET':'riscv64-unknown-elf',
                 'TEST_AS':str(root/'alias/../alias-as'),
                 'TEST_LD':str(root/'alias-ld')}
            for label,override,ok in [
                ('equivalent',{},True),
                ('PATH lookup',{'TEST_AS':'riscv64-unknown-elf-as',
                                'PATH':str(Path(os.environ['RISCV_AS']).parent)+os.pathsep+os.environ['PATH']},True),
                ('different assembler',{'TEST_AS':str(other)},False),
                ('missing linker',{'TEST_LD':str(root/'missing')},False),
                ('wrong target',{'TEST_TARGET':'x86_64-linux-gnu'},False),
            ]:
                with self.subTest(case=label):
                    result=subprocess.run(['bash','-euc','source scripts/riscv_c_toolchain_env.sh'],
                                          cwd=ROOT,env={**env,**override},capture_output=True,text=True)
                    self.assertEqual(result.returncode==0,ok,result.stderr)
                    if not ok:
                        for field in ['[ERROR]','target:','selected as:','reported as:','selected ld:','reported ld:']:
                            self.assertIn(field,result.stderr)

    def test_compiler_resolver_rejects_native_or_missing_gcc(self):
        for compiler in ['/usr/bin/gcc','/nonexistent/cf05-gcc']:
            with self.subTest(compiler=compiler):
                result=subprocess.run(['bash','-c','source scripts/riscv_c_toolchain_env.sh'],
                                      cwd=ROOT,env={**os.environ,'RISCV_GCC':compiler},capture_output=True,text=True)
                self.assertNotEqual(result.returncode,0)
                self.assertIn('[ERROR]',result.stderr)


if __name__=='__main__':unittest.main(verbosity=2)
