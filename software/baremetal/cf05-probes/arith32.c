/* Unsigned arithmetic avoids signed-overflow and left-shift UB. */
unsigned int probe_entry(unsigned int a, unsigned int b) {
    return ((a+b) ^ (a-b)) + (a << 3) + (a >> 5);
}
int probe_signed_shift(int a) { return a >> 3; }
unsigned long probe_widen(unsigned int a) { return a; }
unsigned int probe_variable(unsigned int a, unsigned int amount) {
    amount &= 31;
    return (a << amount) + (a >> amount);
}
int probe_variable_signed(int a, unsigned int amount) { return a >> (amount & 31); }
