//
//  IRSignatureCreator.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 08/10/2018.
//

#import <Foundation/Foundation.h>
#import "IRCryptoKey.h"
#import "IRSignature.h"

@interface EDSigner : NSObject<IRSignatureCreatorProtocol>

- (nonnull instancetype)initWithPrivateKey:(id<IRPrivateKeyProtocol> _Nonnull)privateKey;

@end
