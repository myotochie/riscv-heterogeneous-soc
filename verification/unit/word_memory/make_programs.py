import os,pathlib,subprocess,sys
root=pathlib.Path(sys.argv[1]);root.mkdir(parents=True,exist_ok=True)
def fixture(name,code,writes,trap=None,hazards=0):
    source=root/(name+'.S');obj=root/(name+'.o');elf=root/(name+'.elf');binary=root/(name+'.bin')
    source.write_text('.option norvc\n.option norelax\n.text\n'+code+'\n')
    subprocess.run([os.environ['RISCV_AS'],'-march=rv64i','-mabi=lp64','-o',str(obj),str(source)],check=True)
    subprocess.run([os.environ['RISCV_LD'],'--no-relax','-Ttext=0x80000000','-e','0x80000000','-o',str(elf),str(obj)],check=True)
    subprocess.run([os.environ['RISCV_OBJCOPY'],'-O','binary','--only-section=.text',str(elf),str(binary)],check=True)
    b=binary.read_bytes();assert len(b)%4==0
    (root/(name+'.hex')).write_text(''.join(f'{int.from_bytes(b[i:i+4],"little"):08x}\n' for i in range(0,len(b),4)))
    cause,epc,tval=trap or (0,0,0)
    (root/(name+'.expected')).write_text(f'{int(trap is not None):x} {cause:x} {epc:x} {tval:x} {hazards:x}\n'+''.join(f'{r:x} {v & ((1<<64)-1):x}\n' for r,v in writes))
fixture('data','''
 addi x1,x0,-1
 sd x1,0(x0)
 sw x0,4(x0)
 ld x2,0(x0)
 lw x3,0(x0)
 lw x4,4(x0)
 addi x5,x3,1
 addi x6,x0,2047
 addi x6,x6,2045
 sw x1,0(x6)
 lw x7,0(x6)
 addiw x8,x7,1
 lw x0,0(x6)
 done: jal x0,done
''',[(1,-1),(2,0xffffffff),(3,-1),(4,0),(5,0),(6,2047),(6,4092),(7,-1),(8,0)],hazards=1)
for name,insn,cause,addr in [('load_misaligned','lw x2,2(x0)',4,2),('store_misaligned','sw x1,2(x0)',6,2),('load_range','lw x2,0(x3)',5,4096),('store_range','sw x1,0(x3)',7,4096)]:
 code='addi x1,x0,-1\naddi x3,x0,2047\naddi x3,x3,2047\naddi x3,x3,2\n'+insn+'\naddi x4,x0,99\n.org 0x100\ndone: jal x0,done'
 fixture(name,code,[(1,-1),(3,2047),(3,4094),(3,4096)],(cause,0x80000010,addr))
