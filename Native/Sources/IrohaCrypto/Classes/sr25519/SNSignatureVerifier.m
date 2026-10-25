//
//  SNSignatureVerifier.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import "SNSignatureVerifier.h"
#import "sr25519lib/sr25519.h"

@implementation SNSignatureVerifier

- (BOOL)verify:(nonnull SNSignature*)signature
forOriginalData:(nonnull NSData*)originalData
usingPublicKey:(nonnull SNPublicKey*)publicKey {
    return sr25519_verify(signature.rawData.bytes,
                          originalData.bytes,
                          originalData.length,
                          publicKey.rawData.bytes);
}

@end
