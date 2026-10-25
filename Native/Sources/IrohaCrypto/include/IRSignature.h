//
//  IRSignature.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 08/10/2018.
//

#import <Foundation/Foundation.h>
#import "IRCryptoKey.h"

@protocol IRSignatureProtocol

- (nullable instancetype)initWithRawData:(nonnull NSData*)data error:(NSError*_Nullable*_Nullable)error;
- (nonnull NSData*)rawData;

@end

typedef NS_ENUM(NSUInteger, IRSignatureError) {
    IRSignatureErrorInvalidRawData,
    IRSignatureErrorSignerFailed,
    IRSignatureErrorRecoverFailed
};

@protocol IRSignatureCreatorProtocol

- (nullable id<IRSignatureProtocol>)sign:(nonnull NSData*)originalData
                                   error:(NSError*_Nullable*_Nullable)error;

@end

@protocol IRSignatureVerifierProtocol <NSObject>

- (BOOL)verify:(id<IRSignatureProtocol> _Nonnull)signature
forOriginalData:(nonnull NSData*)originalData
usingPublicKey:(id<IRPublicKeyProtocol> _Nonnull)publicKey;

@end

@protocol IRRecoverableVerifierProtocol <IRSignatureVerifierProtocol>

- (nullable id<IRPublicKeyProtocol>)recoverFromSignature:(id<IRSignatureProtocol> _Nonnull)signature
                                         forOriginalData:(nonnull NSData*)originalData
                                                   error:(NSError*_Nullable*_Nullable)error;

@end
