//
//  IRKeyDeriviationFunction.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 27.02.2020.
//

#import <Foundation/Foundation.h>

@protocol IRKeyDeriviationFunction <NSObject>

- (nullable NSData*)deriveKeyFrom:(nonnull NSData*)password
                             salt:(nonnull NSData*)salt
                           length:(NSUInteger)length
                            error:(NSError*_Nullable*_Nullable)error;
    
@end
