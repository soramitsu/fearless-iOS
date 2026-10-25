//
//  IRCryptoKey.h
//  Pods
//
//  Created by Ruslan Rezin on 07/10/2018.
//

#import <Foundation/Foundation.h>

@protocol IRCryptoKeyProtocol

- (nullable instancetype)initWithRawData:(nonnull NSData*)data error:(NSError*_Nullable*_Nullable)error;
- (nonnull NSData*)rawData;

@end

typedef NS_ENUM(NSUInteger, IRCryptoKeyError) {
    IRCryptoKeyErrorInvalidRawData
};

@protocol IRPrivateKeyProtocol <IRCryptoKeyProtocol>

@end

@protocol IRPublicKeyProtocol <IRCryptoKeyProtocol>

@end
