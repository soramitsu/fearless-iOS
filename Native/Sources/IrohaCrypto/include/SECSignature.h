//
//  SECSignature.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 24.07.2020.
//

#import <Foundation/Foundation.h>
#import "IRSignature.h"

@interface SECSignature : NSObject<IRSignatureProtocol>

+ (NSUInteger)length;

@end
