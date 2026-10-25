//
//  NSData+SHA3.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 14/10/2018.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, IRBlake2Error) {
    IRBlake2InvalidLength,
    IRBlake2AlgoFailed
};

@interface NSData (Blake2)

- (nullable NSData *)blake2s:(NSUInteger)length error:(NSError*_Nullable*_Nullable)error;

// runs blake2s with 32 length
- (nullable NSData *)blake2sWithError:(NSError*_Nullable*_Nullable)error;

- (nullable NSData *)blake2b:(NSUInteger)length error:(NSError*_Nullable*_Nullable)error;

// runs blake2b with 64 length
- (nullable NSData *)blake2bWithError:(NSError*_Nullable*_Nullable)error;

@end
