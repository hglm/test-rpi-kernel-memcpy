# Add -DARMV7 to test armv7 (L1_CACHE_BYTES = 64), otherwise
# armv6 is selected (L1_CACHE_BYTES = 32).

CFLAGS = -std=gnu99 -Ofast -Wall -DARMV6

all : benchmark

benchmark : benchmark.o copy_page.o copy_page_orig.o memcpy.o memcpy_orig.o memset.o memzero.o \
memset_orig.o memzero_orig.o
	$(CC) $(CFLAGS) benchmark.o copy_page.o copy_page_orig.o \
memcpy.o memcpy_orig.o memset.o memset_orig.o memzero.o memzero_orig.o -o benchmark -lm -lrt

clean :
	rm -f benchmark
	rm -f benchmark.o
	rm -f copy_page.o
	rm -f copy_page_orig.o
	rm -f memcpy_orig.o
	rm -f memcpy.o
	rm -f memset.o
	rm -f memset_orig.o
	rm -f memzero.o
	rm -f memzero_orig.o

benchmark.o : benchmark.c asm.h

copy_page_orig.o : copy_page_orig.S kernel_defines_orig.h

copy_page.o : copy_page.S kernel_defines.h

memcpy_orig.o : memcpy_orig.S copy_template_orig.S kernel_defines_orig.h

memcpy.o : memcpy.S copy_template.S kernel_defines.h

memset.o : memset.S kernel_defines.h

memzero.o : memzero.S kernel_defines.h

memset_orig.o : memset_orig.S kernel_defines.h

memzero_orig.o : memzero_orig.S kernel_defines.h

.c.o : 
	$(CC) -c $(CFLAGS) $< -o $@

.S.o :
	$(CC) -c -s $(CFLAGS) $< -o $@

.c.s :
	$(CC) -S $(CFLAGS) $< -o $@
