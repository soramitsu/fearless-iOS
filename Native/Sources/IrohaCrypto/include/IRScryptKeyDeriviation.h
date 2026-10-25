//
//  IRScryptKeyDeriviation.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 27.02.2020.
//

#import <Foundation/Foundation.h>
#import "IRKeyDeriviationFunction.h"

typedef NS_ENUM(NSUInteger, IRScryptKeyDeriviationError) {
    IRScryptFailed
};

@interface IRScryptKeyDeriviation : NSObject<IRKeyDeriviationFunction>

- (nullable NSData*)deriveKeyFrom:(nonnull NSData *)password
                             salt:(nonnull NSData *)salt
                          scryptN:(NSUInteger)scryptN
                          scryptP:(NSUInteger)scryptP
                          scryptR:(NSUInteger)scryptR
                           length:(NSUInteger)length
                            error:(NSError*_Nullable*_Nullable)error;
@end
