//
//  EDPrivateKey_Private.h
//  IrohaCrypto
//
//  Not a public header: shared by EDKeyFactory, EDPrivateKey and EDSigner.
//

#import "EDPrivateKey.h"

// ed25519_sha2_create_keypair writes and ed25519_sha2_sign reads a 64-byte expanded key:
// the clamped scalar (EDPrivateKey rawData), then the RFC 8032 nonce prefix.
enum {
    EDScalarLength = 32,
    EDExpandedKeyLength = 64
};

static inline void EDWipe(void *_Nonnull buffer, size_t length) {
    volatile unsigned char *bytes = buffer;

    while (length--) {
        *bytes++ = 0;
    }
}

@interface EDPrivateKey ()

- (nonnull instancetype)initWithExpandedKey:(const unsigned char *_Nonnull)expandedKey;

// Fills EDExpandedKeyLength bytes. A key created from a raw scalar has no seed to take the
// RFC 8032 prefix from, so its prefix is a domain-separated SHA-512 of the scalar.
- (void)getExpandedKey:(unsigned char *_Nonnull)expandedKey;

@end
