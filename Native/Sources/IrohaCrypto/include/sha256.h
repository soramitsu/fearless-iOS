#ifndef PROJECT_SHA256_H_
#define PROJECT_SHA256_H_

#if defined(__cplusplus)
extern "C" {
#endif

#include "ed25519_export.h"

#define SHA_256_SIZE 32  // bytes

/* implementation-defined sha context size in bytes. */
ED25519_EXPORT extern const unsigned int SHA_256_CONTEXT_SIZE;

/* context is a block of memory of exactly SHA_256_CONTEXT_SIZE bytes */
/* example: unsigned char context[SHA_256_CONTEXT_SIZE]; */

/**
 * Initializes context with specific for implementation size.
 * @param[in] context always pass preallocated buffer of SHA_256_CONTEXT_SIZE;
 * @return 0 if error, non-0 otherwise.
 * @note some implementations may return bad code sometimes, some may not
 */
ED25519_EXPORT extern int sha256_init(void *context);

/**
 * Updates hash state with given buffer
 * @param[in] context always pass preallocated buffer of SHA_256_CONTEXT_SIZE;
 * @param[in] in input buffer with info to be hashed
 * @param[in] inlen buffer size
 * @return 0 if error, non-0 otherwise
 * @note some implementations may return bad code sometimes, some may not
 */
ED25519_EXPORT extern int sha256_update(void *context, const unsigned char *in,
                                        unsigned long long inlen);

/**
 * Finish hash calculation. Use this to store hash in output buffer (out).
 * @param[in] context always pass preallocated buffer of SHA_256_CONTEXT_SIZE;
 * @param[in] out output buffer of exactly SHA_256_SIZE bytes
 * @return 0 if error, non-0 otherwise
 * @note some implementations may return bad code sometimes, some may not
 */
ED25519_EXPORT extern int sha256_final(void *context, unsigned char *out);

/**
 * Inline hash calculation of sha256.
 * @param[out] out output buffer of exactly SHA_256_SIZE bytes
 * @param[in] message message buffer to be hashed
 * @param[in] message_len size of the message buffer
 * @return 0 if error, non-0 otherwise
 * @note some implementations may return bad code sometimes, some may not
 */
ED25519_EXPORT extern int sha256(unsigned char *out, const unsigned char *message,
                                 unsigned long long message_len);

#if defined(__cplusplus)
}
#endif

#endif /* PROJECT_SHA256_H_ */
