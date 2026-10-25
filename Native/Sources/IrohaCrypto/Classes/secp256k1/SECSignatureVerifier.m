//
//  SECSignatureVerifier.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 24.07.2020.
//

#import "SECSignatureVerifier.h"
#import "SECPublicKey.h"
#import "SECSignature.h"
#import "secp256k1.h"

@implementation SECSignatureVerifier

- (nullable id<IRPublicKeyProtocol>)recoverFromSignature:(id<IRSignatureProtocol> _Nonnull)signature
                                         forOriginalData:(nonnull NSData*)originalData
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

    size_t signatureLength = [SECSignature length];
    unsigned char compactSignature[signatureLength];

    memcpy(compactSignature, signature.rawData.bytes, signature.rawData.length);

    int recid = (int)compactSignature[signatureLength - 1];

    if (!(recid >= 0 && recid <= 3)) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Invalid recid"];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRSignatureErrorRecoverFailed
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }


    secp256k1_context *context = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY);
    secp256k1_pubkey rawPublicKey;
    secp256k1_ecdsa_recoverable_signature rawSignature;

    secp256k1_ecdsa_recoverable_signature_parse_compact(context,
                                                        &rawSignature,
                                                        compactSignature,
                                                        recid);


    int status = secp256k1_ecdsa_recover(context, &rawPublicKey, &rawSignature, originalData.bytes);

    if (status == 0) {
        secp256k1_context_destroy(context);

        if (error) {
            NSString *message = [NSString stringWithFormat:@"Public key recovering failed"];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRSignatureErrorRecoverFailed
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    size_t publicKeyLength = [SECPublicKey length];
    unsigned char compresedPubkey[publicKeyLength];

    secp256k1_ec_pubkey_serialize(context,
                                  compresedPubkey,
                                  &publicKeyLength,
                                  &rawPublicKey,
                                  SECP256K1_EC_COMPRESSED);

    secp256k1_context_destroy(context);

    NSData *publicKeyData = [NSData dataWithBytes:compresedPubkey length:publicKeyLength];

    return [[SECPublicKey alloc] initWithRawData:publicKeyData
                                           error:error];
}

- (BOOL)verify:(id<IRSignatureProtocol> _Nonnull)signature
forOriginalData:(nonnull NSData *)originalData
usingPublicKey:(id<IRPublicKeyProtocol> _Nonnull)publicKey {
    id<IRPublicKeyProtocol> resultPublicKey = [self recoverFromSignature:signature
                                                         forOriginalData:originalData
                                                                   error:nil];

    if (!resultPublicKey) {
        return nil;
    }

    return [resultPublicKey.rawData isEqualToData:publicKey.rawData];
}

@end
