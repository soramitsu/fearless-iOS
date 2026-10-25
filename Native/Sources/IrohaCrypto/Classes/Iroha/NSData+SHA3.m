//
//  NSData+SHA3.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 14/10/2018.
//

#import "NSData+SHA3.h"
#import "sha256.h"
#import "sha512.h"

static const int SHA3_256_SIZE = 32;
static const int SHA3_512_SIZE = 64;

@implementation NSData (SHA3)

- (nullable NSData *)sha3:(IRSha3Variant)variant error:(NSError*_Nullable*_Nullable)error {
    int result = 0;
    int size = 0;
    unsigned char *hash = NULL;

    switch (variant) {
        case IRSha3Variant256:
            size = SHA3_256_SIZE;
            hash = malloc(size * sizeof(unsigned char));
            result = sha256(hash, self.bytes, self.length);
            break;
        case IRSha3Variant512:
            size = SHA3_512_SIZE;
            hash = malloc(size * sizeof(unsigned char));
            result = sha512(hash, self.bytes, self.length);
    }

    NSData *hashData = [[NSData alloc] initWithBytes:hash length:size];

    free(hash);

    if (result == 0) {
        if (error) {
            NSString *message = @"Unexpected error";
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRSha3AlgoFailed
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    return hashData;
}

@end
