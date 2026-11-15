typedef unsigned long u64;
__attribute__((noinline)) static u64 inner(u64 a,u64 b) { return a+b; }
__attribute__((noinline)) static u64 middle(u64 a,u64 b) {
    return inner(a,b)+inner(b,3);
}
u64 probe_entry(u64 a,u64 b) { return middle(a,b)+inner(a,5); }
