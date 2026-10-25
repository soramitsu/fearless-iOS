//
//  SECPSigner.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 24.07.2020.
//

#import "SECSigner.h"
#import "SECSignature.h"
#import "secp256k1.h"

@interface SECSigner()

@property(nonatomic, strong)id<IRPrivateKeyProtocol> _Nonnull privateKey;

@end

@implementation SECSigner

- (nonnull instancetype)initWithPrivateKey:(id<IRPrivateKeyProtocol> _Nonnull)privateKey {
    if (self = [super init]) {
        self.privateKey = privateKey;
    }

    return self;
}

- (nullable SECSignature *)sign:(nonnull NSData*)originalData
                              error:(NSError*_Nullable*_Nullable)error {
    if (originalData.length != 32) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Signing data must be 32 byte"];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRSignatureErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    secp256k1_ecdsa_recoverable_signature rawSignature;
    secp256k1_context *context = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);

    int status = secp256k1_ecdsa_sign_recoverable(context,
                                                  &rawSignature,
                                                  originalData.bytes,
                                                  _privateKey.rawData.bytes,
                                                  NULL, NULL);

    secp256k1_context_destroy(context);

    if (status == 0) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Invalid secret key or nonce function failed"];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRSignatureErrorSignerFailed
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    size_t signatureLength = [SECSignature length];
    unsigned char compactSignature[signatureLength];
    int recid;

    secp256k1_ecdsa_recoverable_signature_serialize_compact(context,
                                                            compactSignature,
                                                            &recid,
                                                            &rawSignature);
    compactSignature[signatureLength - 1] = (unsigned char)recid;

    NSData *signatureData = [NSData dataWithBytes:compactSignature length:[SECSignature length]];

    return [[SECSignature alloc] initWithRawData:signatureData
                                           error:error];
}

@end
