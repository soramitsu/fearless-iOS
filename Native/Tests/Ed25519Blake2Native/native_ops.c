// Runs one Ed25519/BLAKE2/SHA operation per input line and prints one result line.
// The same file is linked against the previous XCFramework archives and against the
// vendored sources, so their outputs can be compared byte for byte.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <libed25519/ed25519.h>
#include <libed25519/ed25519_sha2.h>
#include <blake2lib/blake2b.h>
#include <blake2lib/blake2s.h>
#include "sha2_512.h"
#include "sha256.h"
#include "sha512.h"

// Exported by the archive but declared nowhere public: the header names it
// ed25519_sha2_add_scalar, the object file never renamed it.
void ed25519_add_scalar(unsigned char *public_key, unsigned char *private_key,
                        const unsigned char *scalar);
int randombytes(unsigned char *p, int len);

#define MAX_TOKENS 8

static size_t decode(const char *hex, unsigned char **out) {
    if (strcmp(hex, "-") == 0) {
        *out = malloc(1);
        return 0;
    }
    size_t length = strlen(hex) / 2;
    *out = malloc(length ? length : 1);
    for (size_t i = 0; i < length; i++) {
        unsigned int byte;
        if (sscanf(hex + 2 * i, "%2x", &byte) != 1) {
            fprintf(stderr, "bad hex: %s\n", hex);
            exit(2);
        }
        (*out)[i] = (unsigned char)byte;
    }
    return length;
}

static void print_hex(const unsigned char *data, size_t length) {
    if (length == 0) {
        fputc('-', stdout);
    }
    for (size_t i = 0; i < length; i++) {
        printf("%02x", data[i]);
    }
}

static size_t chunk_sizes(const char *list, size_t *sizes, size_t capacity) {
    size_t count = 0;
    const char *cursor = list;
    while (*cursor && count < capacity) {
        sizes[count++] = strtoul(cursor, (char **)&cursor, 10);
        if (*cursor == ',') {
            cursor++;
        }
    }
    return count;
}

// Feeds message to update() in the given chunk sizes, then the remainder.
#define FEED(update, ctx, msg, length, list)                          \
    do {                                                              \
        size_t sizes[64], offset = 0;                                 \
        size_t count = chunk_sizes(list, sizes, 64);                  \
        for (size_t i = 0; i < count && offset < (length); i++) {     \
            size_t take = sizes[i];                                   \
            if (take > (length) - offset) take = (length) - offset;   \
            update(ctx, (msg) + offset, take);                        \
            offset += take;                                           \
        }                                                             \
        update(ctx, (msg) + offset, (length) - offset);               \
    } while (0)

static void run(char **token, int count) {
    const char *op = token[0];
    unsigned char *a = NULL, *b = NULL, *c = NULL;
    size_t la, lb, lc;

    if (strcmp(op, "b2b") == 0 || strcmp(op, "b2s") == 0) {
        int big = op[2] == 'b';
        size_t outlen = strtoul(token[1], NULL, 10);
        la = decode(token[2], &a);
        lb = decode(token[3], &b);
        unsigned char out[64] = {0};
        int rc = big ? blake2b(out, outlen, la ? a : NULL, la, b, lb)
                     : blake2s(out, outlen, la ? a : NULL, la, b, lb);
        printf("%d ", rc);
        print_hex(out, rc == 0 ? outlen : 0);
    } else if (strcmp(op, "b2b_inc") == 0) {
        size_t outlen = strtoul(token[1], NULL, 10);
        la = decode(token[2], &a);
        lb = decode(token[3], &b);
        blake2b_ctx ctx;
        unsigned char out[64];
        int rc = blake2b_init(&ctx, outlen, la ? a : NULL, la);
        if (rc == 0) {
            FEED(blake2b_update, &ctx, b, lb, token[4]);
            blake2b_final(&ctx, out);
        }
        printf("%d ", rc);
        print_hex(out, rc == 0 ? outlen : 0);
    } else if (strcmp(op, "b2s_inc") == 0) {
        size_t outlen = strtoul(token[1], NULL, 10);
        la = decode(token[2], &a);
        lb = decode(token[3], &b);
        blake2s_ctx ctx;
        unsigned char out[32];
        int rc = blake2s_init(&ctx, outlen, la ? a : NULL, la);
        if (rc == 0) {
            FEED(blake2s_update, &ctx, b, lb, token[4]);
            blake2s_final(&ctx, out);
        }
        printf("%d ", rc);
        print_hex(out, rc == 0 ? outlen : 0);
    } else if (strcmp(op, "b2b_init") == 0 || strcmp(op, "b2s_init") == 0) {
        size_t outlen = strtoul(token[1], NULL, 10);
        size_t keylen = strtoul(token[2], NULL, 10);
        unsigned char key[256] = {0};
        blake2b_ctx big;
        blake2s_ctx small;
        int rc = op[2] == 'b' ? blake2b_init(&big, outlen, key, keylen)
                              : blake2s_init(&small, outlen, key, keylen);
        printf("%d", rc);
    } else if (strcmp(op, "sha3_256") == 0 || strcmp(op, "sha3_512") == 0) {
        la = decode(token[1], &a);
        unsigned char out[64];
        int wide = strncmp(op, "sha3_512", 8) == 0;
        int rc = wide ? sha512(out, a, la) : sha256(out, a, la);
        printf("%d ", rc);
        print_hex(out, wide ? 64 : 32);
    } else if (strcmp(op, "sha3_256_inc") == 0 || strcmp(op, "sha3_512_inc") == 0) {
        la = decode(token[1], &a);
        int wide = strncmp(op, "sha3_512", 8) == 0;
        unsigned char *ctx = malloc(wide ? SHA_512_CONTEXT_SIZE : SHA_256_CONTEXT_SIZE);
        unsigned char out[64];
        if (wide) {
            sha512_init(ctx);
            FEED(sha512_update, ctx, a, la, token[2]);
            sha512_final(ctx, out);
        } else {
            sha256_init(ctx);
            FEED(sha256_update, ctx, a, la, token[2]);
            sha256_final(ctx, out);
        }
        free(ctx);
        print_hex(out, wide ? 64 : 32);
    } else if (strcmp(op, "sha2_512") == 0) {
        la = decode(token[1], &a);
        unsigned char out[64];
        int rc = sha2_512(a, la, out);
        printf("%d ", rc);
        print_hex(out, 64);
    } else if (strcmp(op, "sha2_512_inc") == 0) {
        la = decode(token[1], &a);
        sha2_512_context ctx;
        unsigned char out[64];
        sha2_512_init(&ctx);
        FEED(sha2_512_update, &ctx, a, la, token[2]);
        sha2_512_final(&ctx, out);
        print_hex(out, 64);
    } else if (strcmp(op, "ed_keypair") == 0) {
        decode(token[1], &a);
        unsigned char pub[32], priv[64];
        ed25519_sha2_create_keypair(pub, priv, a);
        print_hex(pub, 32);
        putchar(' ');
        print_hex(priv, 64);
    } else if (strcmp(op, "ed_derive") == 0) {
        decode(token[1], &a);
        unsigned char pub[32], priv[64] = {0};
        memcpy(priv, a, 32);
        ed25519_sha2_derive_keypair(pub, priv);
        print_hex(pub, 32);
    } else if (strcmp(op, "ed_sign") == 0) {
        la = decode(token[1], &a);
        decode(token[2], &b);
        decode(token[3], &c);
        unsigned char sig[64];
        ed25519_sha2_sign(sig, a, la, b, c);
        print_hex(sig, 64);
    } else if (strcmp(op, "ed_verify") == 0) {
        decode(token[1], &a);
        lb = decode(token[2], &b);
        decode(token[3], &c);
        printf("%d", ed25519_sha2_verify(a, b, lb, c));
    } else if (strcmp(op, "ed_add_scalar") == 0) {
        la = decode(token[1], &a);
        lb = decode(token[2], &b);
        decode(token[3], &c);
        ed25519_add_scalar(la ? a : NULL, lb ? b : NULL, c);
        print_hex(a, la);
        putchar(' ');
        print_hex(b, lb);
    } else if (strcmp(op, "ed_kex") == 0) {
        decode(token[1], &a);
        decode(token[2], &b);
        unsigned char shared[32];
        ed25519_sha2_key_exchange(shared, a, b);
        print_hex(shared, 32);
    } else if (strcmp(op, "ir_derive") == 0) {
        decode(token[1], &a);
        private_key_t sk;
        public_key_t pk;
        memcpy(sk.data, a, 32);
        ed25519_derive_public_key(&sk, &pk);
        print_hex(pk.data, 32);
    } else if (strcmp(op, "ir_sign") == 0) {
        la = decode(token[1], &a);
        decode(token[2], &b);
        decode(token[3], &c);
        public_key_t pk;
        private_key_t sk;
        signature_t sig;
        memcpy(pk.data, b, 32);
        memcpy(sk.data, c, 32);
        ed25519_sign(&sig, a, la, &pk, &sk);
        print_hex(sig.data, 64);
    } else if (strcmp(op, "ir_verify") == 0) {
        decode(token[1], &a);
        lb = decode(token[2], &b);
        decode(token[3], &c);
        signature_t sig;
        public_key_t pk;
        memcpy(sig.data, a, 64);
        memcpy(pk.data, c, 32);
        printf("%d", ed25519_verify(&sig, b, lb, &pk));
    } else if (strcmp(op, "ir_keypair") == 0) {
        private_key_t sk;
        public_key_t pk, check;
        int rc = ed25519_create_keypair(&sk, &pk);
        ed25519_derive_public_key(&sk, &check);
        printf("%d %d", rc, memcmp(pk.data, check.data, 32) == 0);
    } else if (strcmp(op, "ed_seed") == 0) {
        unsigned char seed[32];
        printf("%d", ed25519_sha2_create_seed(seed));
    } else if (strcmp(op, "randombytes") == 0) {
        unsigned char buffer[256];
        printf("%d", randombytes(buffer, (int)strtoul(token[1], NULL, 10)));
    } else {
        fprintf(stderr, "unknown operation: %s (%d tokens)\n", op, count);
        exit(2);
    }
    putchar('\n');
    free(a);
    free(b);
    free(c);
}

int main(int argc, char **argv) {
    if (argc != 2) {
        fprintf(stderr, "usage: %s operations.txt\n", argv[0]);
        return 2;
    }
    FILE *input = fopen(argv[1], "r");
    if (!input) {
        perror(argv[1]);
        return 2;
    }
    char *line = NULL;
    size_t capacity = 0;
    ssize_t length;
    while ((length = getline(&line, &capacity, input)) > 0) {
        if (line[length - 1] == '\n') {
            line[--length] = '\0';
        }
        char *token[MAX_TOKENS];
        int count = 0;
        for (char *cursor = strtok(line, " "); cursor && count < MAX_TOKENS; cursor = strtok(NULL, " ")) {
            token[count++] = cursor;
        }
        if (count > 0) {
            run(token, count);
        }
    }
    free(line);
    fclose(input);
    return 0;
}
