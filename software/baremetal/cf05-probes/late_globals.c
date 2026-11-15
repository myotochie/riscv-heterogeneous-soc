typedef unsigned long u64;
volatile u64 probe_data=9;
/* Link at ROM+0xf00 to measure the code/data relocation boundary. */
__attribute__((section(".text.late"),noinline))
u64 probe_entry(u64 value) { return probe_data+value; }
