typedef unsigned long u64;
volatile u64 probe_data=7;
volatile u64 probe_bss;
static const u64 table[4]={3,5,7,11};
u64 probe_entry(u64 index) {
    probe_bss=probe_data+table[index & 3];
    return probe_bss;
}
