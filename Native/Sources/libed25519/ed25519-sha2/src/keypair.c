#include "ed25519_sha2.h"
#include "sha2_512.h"
#include "ge.h"


void ed25519_sha2_create_keypair(unsigned char *public_key, unsigned char *private_key, const unsigned char *seed) {
    ge_p3 A;

    sha2_512(seed, 32, private_key);
    private_key[0] &= 248;
    private_key[31] &= 63;
    private_key[31] |= 64;

    ge_scalarmult_base(&A, private_key);
    ge_p3_tobytes(public_key, &A);
}

void ed25519_sha2_derive_keypair(unsigned char *public_key, unsigned char *private_key) {
	ge_p3 A;
	ge_scalarmult_base(&A, private_key);
    ge_p3_tobytes(public_key, &A);
}