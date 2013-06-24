void kernel_copy_page(void *to, const void *from);
void kernel_copy_page_orig(void *to, const void *from);

void *kernel_memcpy_orig(void *dest, const void *src, size_t size);
void *kernel_memcpy(void *dest, const void *src, size_t size);

void *kernel_memset_orig(void *dest, int c, size_t size);
void *kernel_memset(void *dest, int c, size_t size);

void *__kernel_memzero_orig(void *dest, size_t size);
void *__kernel_memzero(void *dest, size_t size);

