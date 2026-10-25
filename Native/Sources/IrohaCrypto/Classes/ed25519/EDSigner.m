//
//  IRSignatureCreator.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 08/10/2018.
//

#import "EDSigner.h"
#import "EDSignature.h"
#import "EDPrivateKey_Private.h"
#import "EDPublicKey.h"
#import "libed25519/ed25519_sha2.h"

@interface EDSigner()

@property(strong, nonatomic)_Nonnull id<IRPrivateKeyProtocol> privateKey;

@end

@implementation EDSigner

- (nonnull instancetype)initWithPrivateKey:(id<IRPrivateKeyProtocol> _Nonnull)privateKey {
    if (self = [super init]) {
        self.privateKey = privateKey;
    }

    return self;
}

- (nullable EDSignature *)sign:(nonnull NSData*)originalData error:(NSError*_Nullable*_Nullable)error {
    EDPrivateKey *privateKey = (EDPrivateKey *)_privateKey;

    if (![privateKey isKindOfClass:[EDPrivateKey class]]) {
        privateKey = [[EDPrivateKey alloc] initWithRawData:_privateKey.rawData error:error];

        if (!privateKey) {
            return nil;
        }
    }

    unsigned char expandedKey[EDExpandedKeyLength];
    [privateKey getExpandedKey:expandedKey];

    NSUInteger publicKeyLength = [EDPublicKey length];
    unsigned char rawPublicKey[publicKeyLength];

    ed25519_sha2_derive_keypair(rawPublicKey, expandedKey);

    NSUInteger signatureLength = [EDSignature length];
    unsigned char signature[signatureLength];

    ed25519_sha2_sign(signature, originalData.bytes, originalData.length, rawPublicKey, expandedKey);
    EDWipe(expandedKey, sizeof(expandedKey));

    NSData *signatureData = [[NSData alloc] initWithBytes:signature
                                                   length:signatureLength];


    return [[EDSignature alloc] initWithRawData:signatureData error:error];
}

@end
