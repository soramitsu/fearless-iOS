//
//  IRCryptoKeyFactory.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 07/10/2018.
//

#import "EDKeyFactory.h"
#import "libed25519/ed25519_sha2.h"
#import "EDPrivateKey_Private.h"
#import "EDPublicKey.h"

@implementation EDKeyFactory

+ (NSUInteger)seedLength {
    return 32;
}

+ (NSUInteger)hashLength {
    return 64;
}

- (nullable id<IRCryptoKeypairProtocol>)createRandomKeypair:(NSError*_Nullable*_Nullable)error {
    NSMutableData *seed = [NSMutableData dataWithLength:[[self class] seedLength]];

    int status = SecRandomCopyBytes(kSecRandomDefault, seed.length, seed.mutableBytes);

    if (status != errSecSuccess) {
        return nil;
    }

    return [self deriveFromSeed:seed error:error];
}

- (id<IRCryptoKeypairProtocol> _Nullable)deriveFromSeed:(nonnull NSData*)seed
                                                  error:(NSError*_Nullable*_Nullable)error {
    if (seed.length != EDScalarLength) {
        if (error) {
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRCryptoKeyErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: @"Ed25519 seed must contain 32 bytes"}];
        }
        return nil;
    }

    NSUInteger hashLength = [[self class] hashLength];
    unsigned char hashBuffer[hashLength];

    NSUInteger publicKeyLength = [EDPublicKey length];
    unsigned char rawPublicKey[publicKeyLength];

    ed25519_sha2_create_keypair(rawPublicKey, hashBuffer, seed.bytes);

    NSData *publicKeyData = [[NSData alloc] initWithBytes:rawPublicKey
                                                   length:publicKeyLength];

    // The private key keeps the second half of the seed hash, the RFC 8032 nonce prefix,
    // so that EDSigner signs exactly as RFC 8032 specifies for this seed.
    EDPrivateKey *privateKey = [[EDPrivateKey alloc] initWithExpandedKey:hashBuffer];
    EDWipe(hashBuffer, hashLength);

    EDPublicKey *publicKey = [[EDPublicKey alloc] initWithRawData:publicKeyData error:error];

    if (!publicKey) {
        return nil;
    }

    return [[IRCryptoKeypair alloc] initPublicKey:publicKey privateKey:privateKey];
}

- (nullable id<IRCryptoKeypairProtocol>)deriveFromPrivateKey:(nonnull id<IRPrivateKeyProtocol>)privateKey
                                                       error:(NSError*_Nullable*_Nullable)error {
    NSData *rawPrivateKey = privateKey.rawData;
    if (rawPrivateKey.length != EDScalarLength) {
        if (error) {
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRCryptoKeyErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: @"Ed25519 scalar must contain 32 bytes"}];
        }
        return nil;
    }

    NSUInteger publicKeyLength = [EDPublicKey length];
    unsigned char rawPublicKey[publicKeyLength];

    ed25519_sha2_derive_keypair(rawPublicKey, (unsigned char*)rawPrivateKey.bytes);

    NSData *publicKeyData = [[NSData alloc] initWithBytes:rawPublicKey length:publicKeyLength];
    EDPublicKey *publicKey = [[EDPublicKey alloc] initWithRawData:publicKeyData error:error];

    if (!publicKey) {
        return nil;
    }

    return [[IRCryptoKeypair alloc] initPublicKey:publicKey
                                       privateKey:privateKey];
}

@end
