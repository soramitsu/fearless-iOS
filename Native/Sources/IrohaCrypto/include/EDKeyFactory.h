//
//  IRIrohaKeyFactory.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 28.02.2020.
//

#import <Foundation/Foundation.h>
#import "IRCryptoKeyFactory.h"

@protocol EDKeyFactoryProtocol <IRCryptoKeyFactoryProtocol>

- (id<IRCryptoKeypairProtocol> _Nullable)deriveFromSeed:(nonnull NSData*)seed
                                                  error:(NSError*_Nullable*_Nullable)error;

@end

@interface EDKeyFactory : NSObject<EDKeyFactoryProtocol>

@end
