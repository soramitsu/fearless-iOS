//
//  IRScryptKeyDeriviation.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 27.02.2020.
//

#import "IRScryptKeyDeriviation.h"
#import "scrypt.h"

static const NSUInteger MEMORY_COST = 16384;
static const NSUInteger PARALELIZATION_FACTOR = 1;
static const NSUInteger BLOCK_SIZE = 8;

@implementation IRScryptKeyDeriviation

- (nullable NSData*)deriveKeyFrom:(NSData *)password
                             salt:(NSData *)salt
                           length:(NSUInteger)length
                            error:(NSError*_Nullable*_Nullable)error {
    return [self deriveKeyFrom:password
                          salt:salt
                       scryptN:MEMORY_COST
                       scryptP:PARALELIZATION_FACTOR
                       scryptR:BLOCK_SIZE
                        length:length
                         error:error];
}

- (nullable NSData*)deriveKeyFrom:(nonnull NSData *)password
                             salt:(nonnull NSData *)salt
                          scryptN:(NSUInteger)scryptN
                          scryptP:(NSUInteger)scryptP
                          scryptR:(NSUInteger)scryptR
                           length:(NSUInteger)length
                            error:(NSError*_Nullable*_Nullable)error {
    uint8_t result[length];

    int status = crypto_scrypt((uint8_t*)(password.bytes),
                               password.length,
                               (uint8_t*)(salt.bytes),
                               salt.length,
                               scryptN,
                               (uint32_t)scryptR,
                               (uint32_t)scryptP,
                               result,
                               length);

    if (status != 0) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Unexpected scrypt status %@ received", @(status)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRScryptFailed
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    return [NSData dataWithBytes:result length:length];
}

@end
