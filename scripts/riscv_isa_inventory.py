#!/usr/bin/env python3
"""CF-05.1 instruction names and audited RTL/test evidence, not ISA compliance."""
import importlib.util
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE_GROUPS = {
    'register': 'ADD SUB SLL SLT SLTU XOR SRL SRA OR AND',
    'immediate': 'ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI',
    'upper': 'LUI AUIPC',
    'load': 'LB LH LW LD LBU LHU LWU',
    'store': 'SB SH SW SD',
    'word_immediate': 'ADDIW SLLIW SRLIW SRAIW',
    'word_register': 'ADDW SUBW SLLW SRLW SRAW',
    'branch': 'BEQ BNE BLT BGE BLTU BGEU',
    'jump': 'JAL JALR',
    'system': 'FENCE ECALL EBREAK',
}
SUPPORTED_BASE = set(('ADD SUB SLL SLT SLTU XOR SRL SRA OR AND ADDI LD SD '
                      'BEQ BNE BLT BGE BLTU BGEU JAL JALR LUI AUIPC SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI '
                      'ADDIW SLLIW SRLIW SRAIW ADDW SUBW SLLW SRLW SRAW LW SW').split())
_spec = importlib.util.spec_from_file_location('cf04_image_guard', ROOT/'scripts/elf_to_hex.py')
_guard = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_guard)


def decode(word):
    op, f3, f7 = word & 127, (word >> 12) & 7, word >> 25
    if op in (0x33, 0x3b):
        table = ({(0,0):'ADD',(32,0):'SUB',(0,1):'SLL',(0,2):'SLT',
                  (0,3):'SLTU',(0,4):'XOR',(0,5):'SRL',(32,5):'SRA',
                  (0,6):'OR',(0,7):'AND'} if op == 0x33 else
                 {(0,0):'ADDW',(32,0):'SUBW',(0,1):'SLLW',(0,5):'SRLW',(32,5):'SRAW'})
        return table.get((f7,f3),'UNKNOWN')
    if op in (0x13,0x1b):
        if op==0x13:
            if f3 in (0,2,3,4,6,7):
                return {0:'ADDI',2:'SLTI',3:'SLTIU',4:'XORI',6:'ORI',7:'ANDI'}[f3]
            return {(0,1):'SLLI',(0,5):'SRLI',(16,5):'SRAI'}.get((word>>26,f3),'UNKNOWN')
        if f3==0:return 'ADDIW'
        return {(0,1):'SLLIW',(0,5):'SRLIW',(32,5):'SRAIW'}.get((f7,f3),'UNKNOWN')
    if op in (0x37,0x17,0x6f):return {0x37:'LUI',0x17:'AUIPC',0x6f:'JAL'}[op]
    if op==0x67:return 'JALR' if f3==0 else 'UNKNOWN'
    if op==0x03:return {0:'LB',1:'LH',2:'LW',3:'LD',4:'LBU',5:'LHU',6:'LWU'}.get(f3,'UNKNOWN')
    if op==0x23:return {0:'SB',1:'SH',2:'SW',3:'SD'}.get(f3,'UNKNOWN')
    if op==0x63:return {0:'BEQ',1:'BNE',4:'BLT',5:'BGE',6:'BLTU',7:'BGEU'}.get(f3,'UNKNOWN')
    if op==0x0f:return {0:'FENCE',1:'FENCE.I'}.get(f3,'UNKNOWN')
    if word in (0x00000073,0x00100073,0x30200073):
        return {0x00000073:'ECALL',0x00100073:'EBREAK',0x30200073:'MRET'}[word]
    if op==0x73:return {1:'CSRRW',2:'CSRRS',3:'CSRRC',5:'CSRRWI',6:'CSRRSI',7:'CSRRCI'}.get(f3,'UNKNOWN')
    return 'UNKNOWN'


def disassembly(text):
    """Parse GNU objdump -d -z -M no-aliases; relocations are separate lines."""
    records=[]
    for line in text.splitlines():
        match=re.match(r'^\s*([0-9a-fA-F]+):\s+([0-9a-fA-F]+)\s+(\S+)',line)
        if not match:continue
        addr,raw,mnemonic=match.groups()
        if len(raw)!=8:
            raise ValueError(f'non-32-bit instruction in rv64i output: {line}')
        word=int(raw,16)
        records.append({'address':int(addr,16),'word':raw.lower(),'instruction':decode(word),
                        'objdump_mnemonic':mnemonic,
                        'image_guard_accepts':_guard.instruction_supported(word)})
    if not records:raise ValueError('no instructions in disassembly')
    return records


def matrix():
    rows=[]
    for group,names in BASE_GROUPS.items():
        for name in names.split():
            supported=name in SUPPORTED_BASE
            evidence=[];integration='not implemented'
            if supported:
                if group=='register':
                    evidence=['verification/unit/decoder/tb_decoder.cpp','verification/unit/alu/tb_alu.cpp']
                    integration='unit ALU/decode evidence; full per-instruction pipeline coverage not established'
                    if name=='ADD':
                        evidence.append('verification/integration/tb_rv64_raw_forwarding.cpp')
                        integration='directed pipeline/RAW tests; not exhaustive'
                elif group=='immediate':
                    evidence=['verification/unit/decoder/tb_decoder.cpp','verification/integration/tb_rv64_pipeline.cpp']
                    integration='directed pipeline and RAW tests'
                    if name!='ADDI':
                        evidence=['verification/unit/immediate_alu/tb_immediate.cpp','verification/integration/tb_immediate_pipeline.cpp']
                        integration='all imm12/funct3 combinations in unit composition; directed pipeline/hazards/annulments, not exhaustive sequential proof'
                elif group in ('load','store'):
                    evidence=['verification/integration/tb_rv64_load.cpp','verification/integration/tb_rv64_store.cpp','verification/integration/tb_rv64_full_width.cpp']
                    integration='directed memory/hazard/fault tests'
                    if name in ('LW','SW'):
                        evidence=['verification/unit/word_memory/tb_word_memory.cpp','verification/integration/tb_word_memory_pipeline.cpp']
                        integration='directed word-size memory, pipeline hazards and precise fault tests'
                elif group=='branch':
                    evidence=['verification/unit/decoder/tb_branch_decoder.cpp','verification/integration/tb_branch_matrix.cpp']
                    integration='directed matrix/hazards/collisions'
                elif group=='upper':
                    evidence=['verification/unit/upper_immediates/tb_upper.cpp','verification/integration/tb_upper_pipeline.cpp']
                    integration='all immediate payloads in unit composition; directed pipeline/bypasses/annulments, not exhaustive sequential proof'
                elif group in ('word_immediate','word_register'):
                    evidence=['verification/unit/word_alu/tb_word.cpp','verification/integration/tb_word_pipeline.cpp']
                    integration='directed pipeline and combinational word-operation tests; not exhaustive sequential proof'
                elif group=='jump':
                    evidence=['verification/unit/decoder/tb_jump_decoder.cpp','verification/integration/tb_jump_pipeline.cpp']
                    integration='directed links/targets/hazards/traps'
            rows.append({'instruction':name,'group':group,'rtl_status':'present' if supported else 'absent',
                         'test_sources':evidence,'coverage_limit':integration,
                         'rtl_source':'rtl/core/decoder/decoder.sv'})
    assert len(rows)==52 and len({r['instruction'] for r in rows})==52
    return rows
