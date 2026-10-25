//
//  IRPrivateKey.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 07/10/2018.
//

#import <Foundation/Foundation.h>
#import "IRCryptoKey.h"

@interface EDPrivateKey : NSObject<IRPrivateKeyProtocol>

+ (NSUInteger)length;

@end
