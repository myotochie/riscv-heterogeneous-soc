#!/usr/bin/env python3
"""Assembled OP-IMM fixtures, explicit architectural expectations, no C execution."""
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
    elf=root/(name+'.elf')
    subprocess.run([os.environ['RISCV_LD'],'--no-relax','-Ttext=0x80000000','-e','0x80000000','-o',str(elf),str(obj)],check=True)
    subprocess.run([os.environ['RISCV_OBJCOPY'],'-O','binary','--only-section=.text',str(elf),str(binary)],check=True)
    data=binary.read_bytes();assert len(data)%4==0 and len(data)<=4096
    (root/(name+'.hex')).write_text(''.join(f'{int.from_bytes(data[i:i+4],"little"):08x}\n' for i in range(0,len(data),4)))
    cause,epc,tval=trap or (0,0,0)
    header=f'{int(trap is not None):x} {cause:x} {epc:x} {tval:x} {hazards:x} {int(name=="mret"):x}\n'
    (root/(name+'.expected')).write_text(header+''.join(f'{rd:x} {value&MASK:x}\n' for rd,value in writes))

fixture('data','''
    addi x1,x0,-1
    slti x2,x1,0
    sltiu x3,x1,-1
    xori x4,x1,-1
    ori x5,x0,-2048
    andi x6,x5,2047
    slli x7,x2,63
    srli x8,x7,63
    srai x9,x7,63
    slli x10,x8,32
    srli x11,x10,32
    srai x12,x7,32
    slti x13,x7,-2048
    sltiu x14,x7,-2048
    srai x15,x1,0
    srli x16,x1,0
    slli x17,x1,0
    xori x18,x0,0
    ori x19,x0,2047
    andi x20,x1,-2048
    xori x0,x1,123
    add x21,x0,x0
    xori x22,x0,1
    xori x22,x0,2
    andi x23,x22,3
    sd x9,0(x0)
    ld x24,0(x0)
    andi x25,x24,255
    ld x13,0(x0)
    xori x8,x9,13
    add x26,x13,x8
    slti x27,x0,-1
    sltiu x28,x0,-1
 done: jal x0,done
''',[(1,-1),(2,1),(3,0),(4,0),(5,-2048),(6,0),(7,1<<63),(8,1),(9,-1),
      (10,1<<32),(11,1),(12,-(1<<31)),(13,1),(14,1),(15,-1),(16,-1),
      (17,-1),(18,0),(19,2047),(20,-2048),(21,0),(22,1),(22,2),(23,2),
      (24,-1),(25,255),(13,-1),(8,-14),(26,-15),(27,0),(28,1)],hazards=1)
fixture('reserved','''
    addi x5,x0,55
    .word 0x04001293
    .word 0x04005293
    .word 0x44005293
    .word 0x80001293
    addi x6,x5,0
 done: jal x0,done
''',[(5,55),(6,55)])
fixture('branch','''
    beq x0,x0,target
    slli x30,x0,63
    xori x31,x0,-1
 target: ori x5,x0,17
 done: jal x0,done
''',[(5,17)])
fixture('trap','''
    xori x5,x0,-1
    ld x6,1(x0)
    slli x7,x0,63
    sltiu x8,x0,-1
    .org 0x100
 done: jal x0,done
''',[(5,-1)],(4,BASE+4,1))
fixture('mret','''
    auipc x1,0
    addi x1,x1,128
    csrrw x0,mepc,x1
    mret
    slli x7,x0,63
    sltiu x8,x0,-1
    .org 0x80
    xori x9,x0,-1
 done: jal x0,done
''',[(1,BASE),(1,BASE+128),(9,-1)])
fixture('control','''
    xori x5,x0,-1
    addi x0,x0,0
    addi x0,x0,0
 done: jal x0,done
''',[(5,-1)])
fixture('control_shift','''
    addi x5,x0,-1
    srai x6,x5,63
    addi x0,x0,0
 done: jal x0,done
''',[(5,-1),(6,-1)])
# Dependency through a branch condition and a load/store address/data.
fixture('consumers','''
    addi x2,x0,-1
    addi x1,x0,7
    andi x2,x1,0
    beq x2,x0,taken
    xori x30,x0,-1
 taken: ori x3,x0,64
    xori x4,x0,-1
    sd x4,0(x3)
    addi x5,x0,1
    slli x5,x5,6
    ld x6,0(x5)
    slti x7,x6,0
 done: jal x0,done
''',[(2,-1),(1,7),(2,0),(3,64),(4,-1),(5,1),(5,64),(6,-1),(7,1)],hazards=1)
