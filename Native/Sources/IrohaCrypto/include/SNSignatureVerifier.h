//
//  SNSignatureVerifier.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import <Foundation/Foundation.h>
#import "SNSignature.h"
#import "SNPublicKey.h"

@protocol SNSignatureVerifierProtocol

- (BOOL)verify:(nonnull SNSignature*)signature
forOriginalData:(nonnull NSData*)originalData
usingPublicKey:(nonnull SNPublicKey*)publicKey;

@end


@interface SNSignatureVerifier : NSObject<SNSignatureVerifierProtocol>

@end
