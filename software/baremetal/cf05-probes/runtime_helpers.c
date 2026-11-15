typedef unsigned long u64;
/* Keep a runtime divisor, explicitly nonzero; inspected, not executed. */
u64 probe_entry(u64 a,u64 divisor) {
    divisor |= 1;
    return a*divisor + a/divisor + a%divisor;
}
