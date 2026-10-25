#include "ed25519_sha2.h"
#include "sha2_512.h"
#include "ge.h"
#include "sc.h"


void ed25519_sha2_sign(unsigned char *signature, const unsigned char *message, size_t message_len, const unsigned char *public_key, const unsigned char *private_key) {
    sha2_512_context hash;
    unsigned char hram[64];
    unsigned char r[64];
    ge_p3 R;


    sha2_512_init(&hash);
    sha2_512_update(&hash, private_key + 32, 32);
    sha2_512_update(&hash, message, message_len);
    sha2_512_final(&hash, r);

    sc_reduce(r);
    ge_scalarmult_base(&R, r);
    ge_p3_tobytes(signature, &R);

    sha2_512_init(&hash);
    sha2_512_update(&hash, signature, 32);
    sha2_512_update(&hash, public_key, 32);
    sha2_512_update(&hash, message, message_len);
    sha2_512_final(&hash, hram);

    sc_reduce(hram);
    sc_muladd(signature + 32, hram, private_key, r);
}
