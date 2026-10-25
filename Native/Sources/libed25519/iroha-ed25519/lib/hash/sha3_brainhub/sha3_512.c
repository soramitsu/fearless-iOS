#include <ed25519/ed25519/errcode.h>
#include <ed25519/ed25519/sha512.h>
#include "sha3.h"

int sha512_init(void *ctx) {
  sha3_Init512((sha3_context *)ctx);
  return ED25519_SUCCESS;
}

int sha512_update(void *ctx, const unsigned char *in,
                  unsigned long long inlen) {
  sha3_Update((sha3_context *)ctx, in, inlen);
  return ED25519_SUCCESS;
}

int sha512_final(void *ctx, unsigned char *out) {
  sha3_Finalize((sha3_context *)ctx, out);
  return ED25519_SUCCESS;
}

extern int sha512(unsigned char *out, const unsigned char *message,
                  unsigned long long message_len) {
  unsigned char ctx[SHA_512_CONTEXT_SIZE];
  sha512_init((void *)ctx);
  sha512_update((void *)ctx, message, message_len);
  sha512_final((void *)ctx, out);
  return ED25519_SUCCESS;
}
