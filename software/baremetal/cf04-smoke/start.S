/* Only instructions implemented by the current core; no libc or pseudo calls. */
.option norvc
.option norelax
.section .text.start,"ax",@progbits
.balign 4
.global _start
.type _start,@function
_start:
    addi x2, x0, 64
    addi x5, x0, 40
    jal  x1, function
    sd   x5, 0(x2)
    ld   x10, 0(x2)
.global done
done:
    jal  x0, done
.size _start, .-_start
.type function,@function
function:
    addi x5, x5, 2
    jalr x0, 0(x1)
.size function, .-function
