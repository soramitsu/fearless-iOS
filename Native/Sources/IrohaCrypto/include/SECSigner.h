//
//  SECPSigner.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 24.07.2020.
//

#import <Foundation/Foundation.h>
#import "IRSignature.h"

@interface SECSigner : NSObject<IRSignatureCreatorProtocol>

- (nonnull instancetype)initWithPrivateKey:(id<IRPrivateKeyProtocol> _Nonnull)privateKey;

@end
