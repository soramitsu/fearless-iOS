#ifndef SHA2_512_H
#define SHA2_512_H

#include <stddef.h>

#include "fixedint.h"

/* state */
typedef struct sha2_512_context_ {
    uint64_t  length, state[8];
    size_t curlen;
    unsigned char buf[128];
} sha2_512_context;


int sha2_512_init(sha2_512_context * md);
int sha2_512_final(sha2_512_context * md, unsigned char *out);
int sha2_512_update(sha2_512_context * md, const unsigned char *in, size_t inlen);
int sha2_512(const unsigned char *message, size_t message_len, unsigned char *out);

#endif
