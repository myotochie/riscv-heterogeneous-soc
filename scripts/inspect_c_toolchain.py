#!/usr/bin/env python3
"""Compile CF-05 probes and report objects, link outcomes and instruction gaps.

Success means the inspection completed with classified link diagnostics. It
never means that these C objects/ELFs executed on the RTL or satisfied an ABI.
"""
import argparse
import collections
import hashlib
import json
import os
import re
from pathlib import Path
import subprocess
import sys

from riscv_isa_inventory import disassembly,matrix

ROOT=Path(__file__).resolve().parents[1]
COMMON=['-march=rv64i','-mabi=lp64','-mno-relax','-ffreestanding','-fno-builtin',
        '-fno-pic','-msmall-data-limit=0','-fno-stack-protector',
        '-fno-unwind-tables','-fno-asynchronous-unwind-tables','-Wall','-Wextra','-Werror']
LAYOUTS=[0,0x100,0x800]


def command(args,log,allow_failure=False,input_text=None):
    result=subprocess.run(args,input=input_text,text=True,capture_output=True,
                          env={**os.environ,'LC_ALL':'C'})
    Path(log).write_text('$ '+json.dumps([str(a) for a in args])+'\n'+result.stdout+result.stderr)
    if result.returncode and not allow_failure:
        raise RuntimeError(f'command failed ({result.returncode}); see {log}')
    return result


def symbols(text):
    result={};undefined=[]
    for line in text.splitlines():
        match=re.match(r'^\s*\d+:\s+([0-9a-fA-F]+)\s+\d+\s+\S+\s+\S+\s+\S+\s+(\S+)\s+(\S+)',line)
        if match:
            value,section,name=match.groups()
            if section=='UND':undefined.append(name)
            else:result[name]=int(value,16)
    return result,sorted(set(undefined))


def counts(records):
    return dict(sorted(collections.Counter(r['instruction'] for r in records).items()))


def inspect(out):
    out.mkdir(parents=True,exist_ok=True)
    gcc=os.environ['RISCV_GCC'];prefix=os.environ['RISCV_GCC_TOOL_PREFIX']
    ld=os.environ['RISCV_LD'];objdump=os.environ['RISCV_OBJDUMP'];readelf=os.environ['RISCV_READELF']
    tools={name:command([os.environ[name],'--version'],out/(name+'.log')).stdout.splitlines()[0]
           for name in ['RISCV_GCC','RISCV_AS','RISCV_LD','RISCV_OBJCOPY','RISCV_OBJDUMP','RISCV_READELF']}
    command([gcc,'-B',prefix,*COMMON,'-print-multi-lib'],out/'gcc-multilib.log')
    command([gcc,'-B',prefix,*COMMON,'-print-libgcc-file-name'],out/'gcc-libgcc-selection.log')
    macros=command([gcc,'-B',prefix,*COMMON,'-dM','-E','-x','c','-'],out/'target-macros.log',input_text='').stdout
    for macro in ['#define __riscv_xlen 64','#define __SIZEOF_INT__ 4','#define __SIZEOF_LONG__ 8']:
        if macro not in macros:raise RuntimeError('unexpected target C type sizes')
    probes=sorted((ROOT/'software/baremetal/cf05-probes').glob('*.c'))
    source_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                   for p in sorted((ROOT/'software/baremetal/cf05-probes').glob('*')) if p.is_file()}
    results=[]
    for probe in probes:
        for optimization in ['O0','O1','O2']:
            for model in ['medlow','medany']:
                work=out/probe.stem/optimization/model;work.mkdir(parents=True,exist_ok=True)
                obj=work/'probe.o'
                command([gcc,'-B',prefix,*COMMON,'-'+optimization,'-mcmodel='+model,
                         '-save-temps=obj','-c',str(probe),'-o',str(obj)],work/'compile.log')
                object_dis=command([objdump,'-d','-z','-M','no-aliases',str(obj)],work/'object-disassembly.log').stdout
                records=disassembly(object_dis)
                command([readelf,'-h','-S','-A','-r','-W',str(obj)],work/'object-readelf.log')
                syms=command([readelf,'-sW',str(obj)],work/'object-symbols.log').stdout
                _,undefined=symbols(syms)
                row={'probe':probe.stem,'optimization':optimization,'code_model':model,
                     'object_instructions':counts(records),
                     'object_unsupported':counts([r for r in records if not r['image_guard_accepts']]),
                     'undefined_symbols':undefined,'layouts':[]}
                for base in LAYOUTS:
                    folder=work/f'ram_{base:03x}';folder.mkdir(exist_ok=True)
                    elf=folder/'probe.elf'
                    # --defsym precedes -T: MEMORY expressions must see the chosen value.
                    linked=command([ld,'--no-relax',f'--defsym=CF05_DATA_BASE={base}',
                                    '-T',str(ROOT/'software/baremetal/cf05-probes/probe.ld'),
                                    '-Map='+str(folder/'probe.map'),'-o',str(elf),str(obj)],
                                   folder/'link.log',allow_failure=True)
                    if linked.returncode:
                        if ('undefined reference' in linked.stderr and probe.stem=='runtime_helpers'
                                and undefined and set(undefined) <= {'__muldi3','__udivdi3','__umoddi3','__udivmoddi4'}
                                and 'relocation truncated' not in linked.stderr):
                            status='unresolved_runtime_helpers'
                        elif ('relocation truncated to fit' in linked.stderr and probe.stem=='function_pointer'
                              and model=='medlow' and 'R_RISCV_HI20' in linked.stderr
                              and 'undefined reference' not in linked.stderr):
                            status='relocation_range_rejected'
                        else:
                            raise RuntimeError(f'unclassified link failure: {folder}/link.log')
                        row['layouts'].append({'ram_base':base,'status':status,'returncode':linked.returncode})
                        continue
                    final=command([objdump,'-d','-z','-M','no-aliases',str(elf)],folder/'linked-disassembly.log').stdout
                    final_records=disassembly(final)
                    command([readelf,'-h','-l','-S','-A','-r','-W',str(elf)],folder/'linked-readelf.log')
                    final_symbols,_=symbols(command([readelf,'-sW',str(elf)],folder/'linked-symbols.log').stdout)
                    if final_symbols.get('CF05_RAM_BASE')!=base:
                        raise RuntimeError('linker RAM_BASE differs from requested layout')
                    row['layouts'].append({'ram_base':base,'status':'linked_not_executed','returncode':0,
                                           'instructions':counts(final_records),
                                           'unsupported':counts([r for r in final_records if not r['image_guard_accepts']]),
                                           'instruction_multiset_changed':counts(final_records)!=counts(records),
                                           'data_symbol':final_symbols.get('probe_data')})
                results.append(row)
    source_files={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted((ROOT/'software/baremetal/cf05-probes').glob('*')) if p.is_file()}
    if source_files != source_hashes:
        raise RuntimeError('probe sources changed during inspection')
    statuses=collections.Counter(item['status'] for row in results for item in row['layouts'])
    object_totals=collections.Counter()
    linked_totals=collections.Counter()
    for row in results:
        object_totals.update(row['object_instructions'])
        for layout in row['layouts']:
            linked_totals.update(layout.get('instructions',{}))
    isa_rows=matrix()
    for row in isa_rows:
        row['object_occurrences']=object_totals[row['instruction']]
        row['linked_occurrences']=linked_totals[row['instruction']]
    report={'meaning':'code-generation inspection only; no C program executed on RTL',
            'gcc':tools['RISCV_GCC'],'tools':tools,'flags':COMMON,
            'ram_bases':LAYOUTS,'optimizations':['O0','O1','O2'],'code_models':['medlow','medany'],
            'probe_sources_sha256':source_files,'object_configurations':len(results),
            'link_outcomes':dict(statuses),'results':results,'isa_matrix':isa_rows}
    matrix_lines=['instruction\tgroup\trtl_status\tobject_occurrences\tlinked_occurrences\tcoverage_limit']
    for row in isa_rows:
        matrix_lines.append('\t'.join(str(row[key]) for key in ['instruction','group','rtl_status','object_occurrences','linked_occurrences','coverage_limit']))
    (out/'isa_matrix.tsv').write_text('\n'.join(matrix_lines)+'\n')
    (out/'inventory.json').write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')
    lines=['probe\toptimization\tmodel\tram_base\tstatus\tunsupported_final']
    for row in results:
        for item in row['layouts']:
            lines.append('\t'.join([row['probe'],row['optimization'],row['code_model'],hex(item['ram_base']),
                                    item['status'],','.join(item.get('unsupported',{}))]))
    (out/'summary.tsv').write_text('\n'.join(lines)+'\n')
    print(json.dumps({'inspection_completed':True,'object_configurations':len(results),'link_outcomes':dict(statuses)}))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    try:inspect(args.output.resolve())
    except (RuntimeError,ValueError,OSError,KeyError) as error:
        parser.exit(1,f'CF05_INSPECTION_ERROR: {error}\n')


if __name__=='__main__':main()
