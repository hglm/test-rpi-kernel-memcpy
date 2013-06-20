void kernel_copy_page(void *to, const void *from);
void kernel_copy_page_orig(void *to, const void *from);

void kernel_memcpy_orig(void *dest, const void *src, size_t size);
void kernel_memcpy(void *dest, const void *src, size_t size);

