// Portable strdup fallback for platforms lacking it
#ifndef COMPAT_H
#define COMPAT_H

#include <stdlib.h>
#include <string.h>

#ifndef HAVE_STRDUP
static inline char* compat_strdup(const char* s) {
    if (!s) return NULL;
    size_t len = strlen(s) + 1;
    char* p = (char*)malloc(len);
    if (p) memcpy(p, s, len);
    return p;
}
#define strdup compat_strdup
#endif

#endif // COMPAT_H