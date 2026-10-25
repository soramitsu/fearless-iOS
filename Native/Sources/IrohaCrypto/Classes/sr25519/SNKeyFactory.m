//
//  SNKeypairFactory.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import "SNKeyFactory.h"
#import "sr25519lib/sr25519.h"


@implementation SNKeyFactory

- (id<SNKeypairProtocol> _Nullable)createKeypairFromSeed:(nonnull NSData*)seed
                                                   error:(NSError*_Nullable*_Nullable)error {
    if ([seed length] != SR25519_SEED_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Invalid seed length %@ but expected %@",
                                 @([seed length]), @(SR25519_SEED_SIZE)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:SNKeyFactoryErrorInvalidSeed
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    uint8_t keypair[SR25519_KEYPAIR_SIZE];

    sr25519_keypair_from_seed(keypair, seed.bytes);

    NSData *keypairData = [NSData dataWithBytes:keypair length:SR25519_KEYPAIR_SIZE];

    return [[SNKeypair alloc] initWithRawData:keypairData error:error];
}

- (id<SNKeypairProtocol> _Nullable)createKeypairHard:(nonnull SNKeypair*)parent
                                           chaincode:(nonnull NSData*)chaincode
                                               error:(NSError*_Nullable*_Nullable)error {
    if ([chaincode length] != SR25519_CHAINCODE_SIZE) {
        if (error) {
            *error = [[self class] createChainCodeError:[chaincode length]];
        }

        return nil;
    }

    uint8_t keypair[SR25519_KEYPAIR_SIZE];

    sr25519_derive_keypair_hard(keypair, parent.rawData.bytes, chaincode.bytes);

    NSData *keypairData = [NSData dataWithBytes:keypair length:SR25519_KEYPAIR_SIZE];

    return [[SNKeypair alloc] initWithRawData:keypairData error:error];
}

- (id<SNKeypairProtocol> _Nullable)createKeypairSoft:(nonnull SNKeypair*)parent
                                           chaincode:(nonnull NSData*)chaincode
                                               error:(NSError*_Nullable*_Nullable)error {
    if ([chaincode length] != SR25519_CHAINCODE_SIZE) {
        if (error) {
            *error = [[self class] createChainCodeError:[chaincode length]];
        }

        return nil;
    }

    uint8_t keypair[SR25519_KEYPAIR_SIZE];

    sr25519_derive_keypair_soft(keypair, parent.rawData.bytes, chaincode.bytes);

    NSData *keypairData = [NSData dataWithBytes:keypair length:SR25519_KEYPAIR_SIZE];

    return [[SNKeypair alloc] initWithRawData:keypairData error:error];
}

- (nullable SNPublicKey*)createPublicKeySoft:(nonnull SNPublicKey*)parentPublicKey
                                   chaincode:(nonnull NSData*)chaincode
                                       error:(NSError*_Nullable*_Nullable)error {
    if ([chaincode length] != SR25519_CHAINCODE_SIZE) {
        if (error) {
            *error = [[self class] createChainCodeError:[chaincode length]];
        }

        return nil;
    }

    uint8_t publicKeyBytes[SR25519_PUBLIC_SIZE];

    sr25519_derive_public_soft(publicKeyBytes, parentPublicKey.rawData.bytes, chaincode.bytes);

    NSData *publicKeyData = [NSData dataWithBytes:publicKeyBytes length:SR25519_KEYPAIR_SIZE];

    return [[SNPublicKey alloc] initWithRawData:publicKeyData error:error];
}

+ (nonnull NSError*)createChainCodeError:(NSUInteger)actualSize {
    NSString *message = [NSString stringWithFormat:@"Invalid chaincode length %@ but expected %@",
                         @(actualSize), @(SR25519_CHAINCODE_SIZE)];
    return [NSError errorWithDomain:NSStringFromClass([self class])
                               code:SNKeyFactoryErrorInvalidChaincode
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end
