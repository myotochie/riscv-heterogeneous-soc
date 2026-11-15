typedef unsigned long u64;
typedef u64 (*callback)(u64);
__attribute__((noinline)) u64 target(u64 value) { return value+1; }
callback probe_entry(void) { return target; }
