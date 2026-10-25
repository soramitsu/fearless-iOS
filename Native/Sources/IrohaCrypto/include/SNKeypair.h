//
//  SNKeypair.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 25.06.2020.
//

#import <Foundation/Foundation.h>
#import "IRCryptoKeypair.h"
#import "SNPrivateKey.h"
#import "SNPublicKey.h"

@protocol SNKeypairProtocol <NSObject>

- (nonnull SNPublicKey*)publicKey;
- (nonnull SNPrivateKey*)privateKey;

- (nonnull NSData*)rawData;

@end

typedef NS_ENUM(NSUInteger, SNKeypairError) {
    SNKeypairErrorInvalidRawData
};

@interface SNKeypair : NSObject<SNKeypairProtocol>

- (nonnull instancetype)initWithPrivateKey:(nonnull SNPrivateKey*)privateKey
                                 publicKey:(nonnull SNPublicKey*)publicKey;

- (nullable instancetype)initWithRawData:(nonnull NSData*)rawData error:(NSError*_Nullable*_Nullable)error;

@end
