#ifndef ED25519_SHA2_H
#define ED25519_SHA2_H

#include <stddef.h>


#ifdef __cplusplus
extern "C" {
#endif

#ifndef ED25519_NO_SEED
int ed25519_sha2_create_seed(unsigned char *seed);
#endif

void ed25519_sha2_create_keypair(unsigned char *public_key, unsigned char *private_key, const unsigned char *seed);
void ed25519_sha2_derive_keypair(unsigned char *public_key, unsigned char *private_key);
void ed25519_sha2_sign(unsigned char *signature, const unsigned char *message, size_t message_len, const unsigned char *public_key, const unsigned char *private_key);
int ed25519_sha2_verify(const unsigned char *signature, const unsigned char *message, size_t message_len, const unsigned char *public_key);
void ed25519_sha2_add_scalar(unsigned char *public_key, unsigned char *private_key, const unsigned char *scalar);
void ed25519_sha2_key_exchange(unsigned char *shared_secret, const unsigned char *public_key, const unsigned char *private_key);


#ifdef __cplusplus
}
#endif

#endif
