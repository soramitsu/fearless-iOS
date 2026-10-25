//
//  IRCryptoKeyFactory.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 07/10/2018.
//

#import <Foundation/Foundation.h>
#import "IRCryptoKeypair.h"

typedef NS_ENUM(NSUInteger, IRCryptoKeyFactoryError) {
    IRCryptoKeyFactoryErrorGeneratorFailed,
    IRCryptoKeyFactoryErrorDeriviationFailed
};

@protocol IRCryptoKeyFactoryProtocol <NSObject>

- (id<IRCryptoKeypairProtocol> _Nullable)createRandomKeypair:(NSError*_Nullable*_Nullable)error;
- (id<IRCryptoKeypairProtocol> _Nullable)deriveFromPrivateKey:(id<IRPrivateKeyProtocol> _Nonnull)privateKey
                                                        error:(NSError*_Nullable*_Nullable)error;

@end
