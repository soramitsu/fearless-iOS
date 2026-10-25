#include "ed25519_sha2.h"

#ifndef ED25519_NO_SEED

#include <stdio.h>

int ed25519_sha2_create_seed(unsigned char *seed) {
    FILE *f = fopen("/dev/urandom", "rb");

    if (f == NULL) {
        return 1;
    }

    fread(seed, 1, 32, f);
    fclose(f);

    return 0;
}

#endif
