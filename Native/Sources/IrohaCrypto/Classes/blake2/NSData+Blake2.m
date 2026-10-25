//
//  NSData+SHA3.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 14/10/2018.
//

#import "NSData+Blake2.h"
#import "blake2lib/blake2s.h"
#import "blake2lib/blake2b.h"

static const int BLAKE2s_MAX_SIZE = 32;
static const int BLAKE2b_MAX_SIZE = 64;

@implementation NSData (SHA3)

- (nullable NSData *)blake2s:(NSUInteger)length error:(NSError*_Nullable*_Nullable)error {
    if (length > BLAKE2s_MAX_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Length must be not greater then %@", @(BLAKE2s_MAX_SIZE)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRBlake2InvalidLength
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        
        return nil;
    }

    uint8_t hash[length];

    int result = blake2s(hash, length, NULL, 0, [self bytes], [self length]);

    if (result != 0) {
        if (error) {
            NSString *message = @"Unexpected error";
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRBlake2AlgoFailed
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    return [NSData dataWithBytes:hash length:length];
}

- (nullable NSData *)blake2sWithError:(NSError*_Nullable*_Nullable)error {
    return [self blake2s:BLAKE2s_MAX_SIZE error:error];
}

- (nullable NSData *)blake2b:(NSUInteger)length error:(NSError*_Nullable*_Nullable)error {
    if (length > BLAKE2b_MAX_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Length must be not greater then %@", @(BLAKE2b_MAX_SIZE)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRBlake2InvalidLength
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    uint8_t hash[length];

    int result = blake2b(hash, length, NULL, 0, [self bytes], [self length]);

    if (result != 0) {
        if (error) {
            NSString *message = @"Unexpected error";
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRBlake2AlgoFailed
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    return [NSData dataWithBytes:hash length:length];
}

// runs blake2b with 64 length
- (nullable NSData *)blake2bWithError:(NSError*_Nullable*_Nullable)error {
    return [self blake2b:BLAKE2b_MAX_SIZE error:error];
}

@end
