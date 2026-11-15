/* Code-generation probe, not a standalone bootable program. */
typedef unsigned long u64;
u64 probe_entry(u64 a, u64 b) {
    return ((a+b) ^ (a-b)) + ((a & b) | (a << 5)) + (a >> 3) + (a < b);
}
u64 probe_immediates(u64 a) { return ((a ^ 0x55UL) | 0x12UL) & 0x3ffUL; }
long probe_signed(long a) { return (a >> 4) + (a < -7); }
u64 probe_unsigned_compare(u64 a) { return a < 31; }
u64 probe_variable(u64 a, unsigned int amount) { return (a << (amount & 63)) + (a >> (amount & 63)); }
long probe_signed_control(long a, long b) {
    if (a < 0) return a & b;
    if (a < b) return a | b;
    return a^b;
}
