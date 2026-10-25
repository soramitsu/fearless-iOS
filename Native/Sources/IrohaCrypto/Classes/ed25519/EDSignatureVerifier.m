//
//  IRSignatureVerifier.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 08/10/2018.
//

#import "EDSignatureVerifier.h"
#import "libed25519/ed25519_sha2.h"

@implementation EDSignatureVerifier

- (BOOL)verify:(id<IRSignatureProtocol> _Nonnull)signature
forOriginalData:(nonnull NSData *)originalData
usingPublicKey:(id<IRPublicKeyProtocol> _Nonnull)publicKey {
    int result = ed25519_sha2_verify(signature.rawData.bytes,
                                     originalData.bytes,
                                     originalData.length,
                                     publicKey.rawData.bytes);

    return result == 1;
}

@end
