//
//  IRSignatureCreator.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 08/10/2018.
//

#import "IRIrohaSigner.h"
#import "IRIrohaSignature.h"
#import "libed25519/ed25519.h"

@interface IRIrohaSigner()

@property(strong, nonatomic)_Nonnull id<IRPrivateKeyProtocol> privateKey;

@end

@implementation IRIrohaSigner

- (nonnull instancetype)initWithPrivateKey:(id<IRPrivateKeyProtocol> _Nonnull)privateKey {
    if (self = [super init]) {
        self.privateKey = privateKey;
    }

    return self;
}

- (nullable IRIrohaSignature *)sign:(nonnull NSData*)originalData
                              error:(NSError*_Nullable*_Nullable)error {
    private_key_t private_key;
    public_key_t public_key;

    memcpy(private_key.data, _privateKey.rawData.bytes, ed25519_privkey_SIZE);

    ed25519_derive_public_key(&private_key, &public_key);

    signature_t signature;

    ed25519_sign(&signature, originalData.bytes, originalData.length, &public_key, &private_key);

    NSData *signatureData = [[NSData alloc] initWithBytes:signature.data
                                                   length:ed25519_signature_SIZE];


    return [[IRIrohaSignature alloc] initWithRawData:signatureData error:error];
}

@end
