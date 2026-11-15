typedef unsigned long u64;
u64 probe_entry(const u64 *array, u64 n) {
    u64 sum=0;
    for (u64 i=0;i<n;++i) sum+=array[i];
    return sum;
}
u64 probe_loads(const signed char *a, const unsigned char *b,
                const short *c, const unsigned short *d,
                const int *e, const unsigned int *f) {
    return (u64)(long)*a + *b + (u64)(long)*c + *d + (u64)(long)*e + *f;
}
void probe_stores(volatile unsigned char *a, volatile unsigned short *b,
                  volatile unsigned int *c, volatile u64 *d, u64 value) {
    *a=value; *b=value; *c=value; *d=value;
}
