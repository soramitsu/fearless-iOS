//
//  IRIrohaSignature.h
//  Pods
//
//  Created by Ruslan Rezin on 28.02.2020.
//

#import <Foundation/Foundation.h>
#import "IRSignature.h"

@interface EDSignature : NSObject<IRSignatureProtocol>

+ (NSUInteger)length;

@end
