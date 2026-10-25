// Line-oriented driver for one sr25519lib static archive.
// usage: sr25519_tool <commands-file>   -> one result line per command on stdout
// Built once per library (4.0.4 pin and RC pin, device and simulator slices) so the
// same commands can be replayed against each binary.
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SR25519_SEED_SIZE 32
#define SR25519_CHAINCODE_SIZE 32
#define SR25519_PUBLIC_SIZE 32
#define SR25519_SECRET_SIZE 64
#define SR25519_SIGNATURE_SIZE 64
#define SR25519_KEYPAIR_SIZE 96

void sr25519_keypair_from_seed(uint8_t *keypair_out, const uint8_t *seed_ptr);
void sr25519_derive_keypair_hard(uint8_t *keypair_out, const uint8_t *pair_ptr, const uint8_t *cc_ptr);
void sr25519_derive_keypair_soft(uint8_t *keypair_out, const uint8_t *pair_ptr, const uint8_t *cc_ptr);
void sr25519_derive_public_soft(uint8_t *pubkey_out, const uint8_t *public_ptr, const uint8_t *cc_ptr);
void sr25519_from_ed25519_bytes(uint8_t *secret_out, const uint8_t *secret_ptr);
void sr25519_to_ed25519_bytes(uint8_t *secret_out, const uint8_t *secret_ptr);
void sr25519_sign(uint8_t *signature_out, const uint8_t *public_ptr, const uint8_t *secret_ptr,
                  const uint8_t *message_ptr, unsigned long message_length);
bool sr25519_verify(const uint8_t *signature_ptr, const uint8_t *message_ptr,
                    unsigned long message_length, const uint8_t *public_ptr);
#ifdef CHECKED_SIGN
int sr25519_sign_checked(uint8_t *signature_out, size_t signature_out_length,
                         const uint8_t *public_ptr, size_t public_length,
                         const uint8_t *secret_ptr, size_t secret_length,
                         const uint8_t *message_ptr, size_t message_length);
#endif

static size_t unhex(const char *text, uint8_t *out, size_t capacity) {
    if (strcmp(text, "-") == 0) return 0;
    size_t length = strlen(text) / 2;
    if (length > capacity) { fprintf(stderr, "input too long\n"); exit(2); }
    for (size_t i = 0; i < length; i++) {
        unsigned int byte;
        if (sscanf(text + 2 * i, "%2x", &byte) != 1) { fprintf(stderr, "bad hex\n"); exit(2); }
        out[i] = (uint8_t)byte;
    }
    return length;
}

static void need(size_t actual, size_t expected, const char *what) {
    if (actual != expected) { fprintf(stderr, "%s: %zu bytes, expected %zu\n", what, actual, expected); exit(2); }
}

static void hex(const uint8_t *bytes, size_t length) {
    for (size_t i = 0; i < length; i++) printf("%02x", bytes[i]);
}

int main(int argc, char **argv) {
    if (argc != 2) { fprintf(stderr, "usage: %s <commands-file>\n", argv[0]); return 2; }
    FILE *input = fopen(argv[1], "r");
    if (!input) { perror("open"); return 2; }

    static char line[70000];
    static uint8_t a[20000], b[20000], c[20000], out[128];
    while (fgets(line, sizeof line, input)) {
        char *cmd = strtok(line, " \n");
        if (!cmd || cmd[0] == '#') continue;
        char *x = strtok(NULL, " \n"), *y = strtok(NULL, " \n"), *z = strtok(NULL, " \n");
        if (strcmp(cmd, "fromseed") == 0) {
            need(unhex(x, a, sizeof a), SR25519_SEED_SIZE, "seed");
            sr25519_keypair_from_seed(out, a);
            hex(out, SR25519_KEYPAIR_SIZE);
        } else if (strcmp(cmd, "hard") == 0 || strcmp(cmd, "soft") == 0) {
            need(unhex(x, a, sizeof a), SR25519_KEYPAIR_SIZE, "keypair");
            need(unhex(y, b, sizeof b), SR25519_CHAINCODE_SIZE, "chaincode");
            if (cmd[0] == 'h') sr25519_derive_keypair_hard(out, a, b);
            else sr25519_derive_keypair_soft(out, a, b);
            hex(out, SR25519_KEYPAIR_SIZE);
        } else if (strcmp(cmd, "softpub") == 0) {
            need(unhex(x, a, sizeof a), SR25519_PUBLIC_SIZE, "public");
            need(unhex(y, b, sizeof b), SR25519_CHAINCODE_SIZE, "chaincode");
            sr25519_derive_public_soft(out, a, b);
            hex(out, SR25519_PUBLIC_SIZE);
        } else if (strcmp(cmd, "fromed") == 0 || strcmp(cmd, "toed") == 0) {
            need(unhex(x, a, sizeof a), SR25519_SECRET_SIZE, "secret");
            if (cmd[0] == 'f') sr25519_from_ed25519_bytes(out, a);
            else sr25519_to_ed25519_bytes(out, a);
            hex(out, SR25519_SECRET_SIZE);
        } else if (strcmp(cmd, "sign") == 0) {
            // sign <public> <secret> <message|->  : the unchecked entry point 4.0.4 called
            need(unhex(x, a, sizeof a), SR25519_PUBLIC_SIZE, "public");
            need(unhex(y, b, sizeof b), SR25519_SECRET_SIZE, "secret");
            size_t length = unhex(z, c, sizeof c);
            sr25519_sign(out, a, b, c, (unsigned long)length);
            hex(out, SR25519_SIGNATURE_SIZE);
        } else if (strcmp(cmd, "signchecked") == 0) {
            // signchecked <public> <secret> <message|-> : the entry point SNSigner calls in the RC
#ifdef CHECKED_SIGN
            size_t public_length = unhex(x, a, sizeof a);
            size_t secret_length = unhex(y, b, sizeof b);
            size_t length = unhex(z, c, sizeof c);
            memset(out, 0xa5, SR25519_SIGNATURE_SIZE);
            int result = sr25519_sign_checked(out, SR25519_SIGNATURE_SIZE, a, public_length,
                                              b, secret_length, length ? c : NULL, length);
            printf("%d ", result);
            hex(out, SR25519_SIGNATURE_SIZE);
#else
            printf("unsupported");
#endif
        } else if (strcmp(cmd, "verify") == 0) {
            // verify <signature> <message|-> <public>
            need(unhex(x, a, sizeof a), SR25519_SIGNATURE_SIZE, "signature");
            size_t length = unhex(y, b, sizeof b);
            need(unhex(z, c, sizeof c), SR25519_PUBLIC_SIZE, "public");
            printf("%d", sr25519_verify(a, b, (unsigned long)length, c) ? 1 : 0);
        } else {
            fprintf(stderr, "unknown command %s\n", cmd);
            return 2;
        }
        printf("\n");
    }
    fclose(input);
    return 0;
}
