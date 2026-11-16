#!/usr/bin/env python3
"""Directed assembly fixtures with independently stated architectural results."""
import os
from pathlib import Path
import subprocess
import sys
root=Path(sys.argv[1]);root.mkdir(parents=True,exist_ok=True)
BASE=0x80000000
MASK=(1<<64)-1

def fixture(name,code,writes,trap=None,hazards=0):
    source=root/(name+'.S');obj=root/(name+'.o');binary=root/(name+'.bin')
    source.write_text('.option norvc\n.option norelax\n.text\n'+code+'\n')
    subprocess.run([os.environ['RISCV_AS'],'-march=rv64i_zicsr','-mabi=lp64','-mno-relax','-o',str(obj),str(source)],check=True)
    # Local branch/jump relocations must be resolved by the linker.
    elf=root/(name+'.elf')
    subprocess.run([os.environ['RISCV_LD'],'--no-relax','-Ttext=0x80000000','-e','0x80000000','-o',str(elf),str(obj)],check=True)
    subprocess.run([os.environ['RISCV_OBJCOPY'],'-O','binary','--only-section=.text',str(elf),str(binary)],check=True)
    data=binary.read_bytes();assert len(data)%4==0 and len(data)<=4096
    (root/(name+'.hex')).write_text(''.join(f'{int.from_bytes(data[i:i+4],"little"):08x}\n' for i in range(0,len(data),4)))
    # First line: expected trap count/cause/EPC/tval, load-use stalls, MRET count.
    cause,epc,tval=trap or (0,0,0)
    header=f'{int(trap is not None):x} {cause:x} {epc:x} {tval:x} {hazards:x} {int(name=="mret"):x}\n'
    (root/(name+'.expected')).write_text(header+''.join(f'{rd:x} {value&MASK:x}\n' for rd,value in writes))

fixture('data', '''
    lui x5,0x80000
    addi x6,x5,1
    add x7,x5,x6
    lui x8,0x7ffff
    auipc x9,0
    addi x10,x9,8
    lui x0,0xfffff
    add x11,x0,x0
    lui x12,0
    sd x6,0(x12)
    ld x13,0(x12)
    lui x14,0x68
    addi x15,x14,2
    auipc x16,0
    addi x16,x16,16
    jalr x0,0(x16)
    lui x30,0xdead
    add x17,x0,x13
    addi x18,x0,77
    lui x19,0
    sd x18,0(x19)
    ld x20,0(x19)
    addi x21,x20,1
    lui x22,1
    lui x22,2
    add x23,x22,x0
 done: jal x0,done
''', [(5,0xffffffff80000000),(6,0xffffffff80000001),(7,0xffffffff00000001),
      (8,0x7ffff000),(9,BASE+16),(10,BASE+24),(11,0),(12,0),
      (13,0xffffffff80000001),(14,0x68000),(15,0x68002),
      (16,BASE+52),(16,BASE+68),(17,0xffffffff80000001),
      (18,77),(19,0),(20,77),(21,78),(22,4096),(22,8192),(23,8192)],hazards=1)
fixture('branch','''
    beq x0,x0,target
    lui x30,0x80000
    auipc x31,0
 target: lui x5,0xfffff
 done: jal x0,done
''',[(5,0xfffffffffffff000)])
fixture('trap','''
    lui x5,0x80000
    ld x6,1(x0)
    lui x7,0x12345
    auipc x8,0
    .org 0x100
 done: jal x0,done
''',[(5,0xffffffff80000000)],(4,BASE+4,1))
fixture('mret','''
    auipc x1,0
    addi x1,x1,128
    csrrw x0,mepc,x1
    mret
    lui x7,0x12345
    auipc x8,0
    .org 0x80
    lui x9,0xfffff
 done: jal x0,done
''',[(1,BASE),(1,BASE+128),(9,0xfffffffffffff000)])
fixture('control','''
    lui x5,0x80000
    addi x0,x0,0
    addi x0,x0,0
 done: jal x0,done
''',[(5,0xffffffff80000000)])

fixture('edges',"""
    lui x5,0x80000
    auipc x6,0x80000
    auipc x7,0xfffff
 done: jal x0,done
""",[(5,0xffffffff80000000),(6,4),(7,0x7ffff008)])

fixture('memory',"""
    sd x0,56(x0)
    addi x9,x0,2040
    addi x9,x9,2047
    addi x9,x9,1
    sd x0,-8(x9)
    lui x5,0x80000
    sd x5,0(x9)
    ld x6,0(x9)
    addi x7,x0,64
    lui x7,1
    ld x8,-8(x7)
    addi x10,x0,64
    lui x10,1
    sd x5,-16(x10)
    ld x11,-8(x9)
 done: jal x0,done
""",[(9,2040),(9,4087),(9,4088),(5,0xffffffff80000000),
      (6,0xffffffff80000000),(7,64),(7,4096),(8,0xffffffff80000000),
      (10,64),(10,4096),(11,0xffffffff80000000)])

fixture('control_pc',"""
    auipc x5,0
    addi x0,x0,0
    addi x0,x0,0
 done: jal x0,done
""",[(5,BASE)])
fixture('jump',"""
    addi x5,x0,64
    auipc x5,0
    jalr x1,16(x5)
    lui x30,0xdead
    auipc x31,0
    addi x6,x1,0
 done: jal x0,done
""",[(5,64),(5,BASE+4),(1,BASE+12),(6,BASE+12)])
