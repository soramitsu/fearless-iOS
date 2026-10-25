#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sr25519.h"

static void hex(const char *name, const uint8_t *bytes, size_t count) {
    printf("%s=", name);
    for (size_t i = 0; i < count; i++) printf("%02x", bytes[i]);
    putchar('\n');
}

static bool from_hex(const char *text, uint8_t *bytes, size_t count) {
    if (strlen(text) != count * 2) return false;
    for (size_t i = 0; i < count; i++) {
        unsigned value;
        if (sscanf(text + 2 * i, "%2x", &value) != 1) return false;
        bytes[i] = (uint8_t)value;
    }
    return true;
}

int main(int argc, char **argv) {
    uint8_t seed[SR25519_SEED_SIZE];
    uint8_t chaincode[SR25519_CHAINCODE_SIZE];
    for (size_t i = 0; i < sizeof(seed); i++) {
        seed[i] = (uint8_t)i;
        chaincode[i] = (uint8_t)(31 - i);
    }
    uint8_t pair[SR25519_KEYPAIR_SIZE];
    sr25519_keypair_from_seed(pair, seed);
    hex("pair", pair, sizeof(pair));

    uint8_t hard[SR25519_KEYPAIR_SIZE];
    uint8_t soft[SR25519_KEYPAIR_SIZE];
    uint8_t public_soft[SR25519_PUBLIC_SIZE];
    sr25519_derive_keypair_hard(hard, pair, chaincode);
    sr25519_derive_keypair_soft(soft, pair, chaincode);
    sr25519_derive_public_soft(public_soft, pair + SR25519_SECRET_SIZE, chaincode);
    hex("hard", hard, sizeof(hard));
    hex("soft", soft, sizeof(soft));
    hex("public_soft", public_soft, sizeof(public_soft));
    if (memcmp(public_soft, soft + SR25519_SECRET_SIZE, sizeof(public_soft)) != 0) return 2;

    uint8_t ed[SR25519_SECRET_SIZE];
    uint8_t converted[SR25519_SECRET_SIZE];
    sr25519_to_ed25519_bytes(ed, pair);
    sr25519_from_ed25519_bytes(converted, ed);
    hex("ed", ed, sizeof(ed));
    hex("converted", converted, sizeof(converted));
    if (memcmp(converted, pair, sizeof(converted)) != 0) return 3;

    const uint8_t message[] = "SR25519 compatibility vector";
    uint8_t signature[SR25519_SIGNATURE_SIZE];
    sr25519_sign(signature, pair + SR25519_SECRET_SIZE, pair,
                 message, sizeof(message) - 1);
    hex("signature", signature, sizeof(signature));
    if (!sr25519_verify(signature, message, sizeof(message) - 1,
                        pair + SR25519_SECRET_SIZE)) return 4;

    if (argc > 1) {
        uint8_t other[SR25519_SIGNATURE_SIZE];
        if (!from_hex(argv[1], other, sizeof(other))) return 5;
        if (!sr25519_verify(other, message, sizeof(message) - 1,
                            pair + SR25519_SECRET_SIZE)) return 6;
    }

#ifdef CHECKED_SIGN
    uint8_t checked[SR25519_SIGNATURE_SIZE];
    Sr25519SignResult result = sr25519_sign_checked(
        checked, sizeof(checked), pair + SR25519_SECRET_SIZE, SR25519_PUBLIC_SIZE,
        pair, SR25519_SECRET_SIZE, message, sizeof(message) - 1);
    if (result != Sr25519SignOk ||
        !sr25519_verify(checked, message, sizeof(message) - 1,
                        pair + SR25519_SECRET_SIZE)) return 7;
    uint8_t invalid_secret[SR25519_SECRET_SIZE];
    uint8_t invalid_public[SR25519_PUBLIC_SIZE];
    memset(invalid_secret, 0xff, sizeof(invalid_secret));
    memset(invalid_public, 0xff, sizeof(invalid_public));
    result = sr25519_sign_checked(checked, sizeof(checked),
        pair + SR25519_SECRET_SIZE, SR25519_PUBLIC_SIZE,
        invalid_secret, sizeof(invalid_secret), message, sizeof(message) - 1);
    if (result != Sr25519SignInvalidSecret) return 8;
    result = sr25519_sign_checked(checked, sizeof(checked),
        invalid_public, sizeof(invalid_public),
        pair, SR25519_SECRET_SIZE, message, sizeof(message) - 1);
    if (result != Sr25519SignInvalidPublic) return 9;
    hex("checked", checked, sizeof(checked));
#endif
    return 0;
}
