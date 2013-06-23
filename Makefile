# Add -DSUNXI to test armv7 (L1_CACHE_BYTES = 64), otherwise
# armv6 is selected (L1_CACHE_BYTES = 32).

CFLAGS = -std=gnu99 -Ofast -Wall -DSUNXI

all : benchmark

benchmark : benchmark.o copy_page.o copy_page_orig.o memcpy.o memcpy_orig.o
	$(CC) $(CFLAGS) benchmark.o copy_page.o copy_page_orig.o \
memcpy.o memcpy_orig.o -o benchmark -lm -lrt

clean :
	rm -f benchmark
	rm -f benchmark.o
	rm -f copy_page.o
	rm -f copy_page_orig.o
	rm -f memcpy_orig.o
	rm -f memcpy.o

benchmark.o : benchmark.c asm.h

copy_page_orig.o : copy_page_orig.S kernel_defines_orig.h

copy_page.o : copy_page.S kernel_defines.h

memcpy_orig.o : memcpy_orig.S copy_template_orig.S kernel_defines_orig.h

memcpy.o : memcpy.S copy_template.S kernel_defines.h

.c.o : 
	$(CC) -c $(CFLAGS) $< -o $@

.S.o :
	$(CC) -c -s $(CFLAGS) $< -o $@

.c.s :
	$(CC) -S $(CFLAGS) $< -o $@
