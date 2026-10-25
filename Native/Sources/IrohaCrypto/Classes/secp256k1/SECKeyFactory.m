//
//  SECKeyFactory.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 24.07.2020.
//

#import "SECKeyFactory.h"
#import "secp256k1.h"
#import "SECPrivateKey.h"
#import "SECPublicKey.h"

@implementation SECKeyFactory

- (nullable id<IRCryptoKeypairProtocol>)createRandomKeypair:(NSError*_Nullable*_Nullable)error {
    NSMutableData *seed = [NSMutableData dataWithLength:[SECPrivateKey length]];

    int status = SecRandomCopyBytes(kSecRandomDefault, seed.length, seed.mutableBytes);

    if (status != errSecSuccess) {
        return nil;
    }

    SECPrivateKey *privateKey = [[SECPrivateKey alloc] initWithRawData:seed
                                                                 error:error];

    if (!privateKey) {
        return nil;
    }

    return [self deriveFromPrivateKey:privateKey error:error];
}

- (nullable id<IRCryptoKeypairProtocol>)deriveFromPrivateKey:(nonnull id<IRPrivateKeyProtocol>)privateKey
                                                       error:(NSError*_Nullable*_Nullable)error {

    secp256k1_pubkey rawPublicKey;

    secp256k1_context *context = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);

    int status = secp256k1_ec_pubkey_create(context,
                                            &rawPublicKey,
                                            privateKey.rawData.bytes);

    if (status == 0) {
        secp256k1_context_destroy(context);

        if (error) {
            NSString *message = [NSString stringWithFormat:@"Secret key is invalid"];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRCryptoKeyFactoryErrorDeriviationFailed
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    size_t compressedLength = [SECPublicKey length];
    unsigned char compresedPubkey[compressedLength];

    secp256k1_ec_pubkey_serialize(context,
                                  compresedPubkey,
                                  &compressedLength,
                                  &rawPublicKey,
                                  SECP256K1_EC_COMPRESSED);

    secp256k1_context_destroy(context);

    NSData *publicKeyData = [NSData dataWithBytes:compresedPubkey length:[SECPublicKey length]];
    SECPublicKey *publicKey = [[SECPublicKey alloc] initWithRawData: publicKeyData error:error];

    if (!publicKey) {
        return nil;
    }

    return [[IRCryptoKeypair alloc] initPublicKey:publicKey privateKey:privateKey];
}

@end
