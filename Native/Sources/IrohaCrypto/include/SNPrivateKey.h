//
//  SNPrivateKey.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import <Foundation/Foundation.h>
#import "IRCryptoKey.h"

@interface SNPrivateKey : NSObject<IRPrivateKeyProtocol>

- (nullable instancetype)initWithFromEd25519:(nonnull NSData*)data
                                       error:(NSError*_Nullable*_Nullable)error;

- (nonnull NSData*)toEd25519Data;

@end
