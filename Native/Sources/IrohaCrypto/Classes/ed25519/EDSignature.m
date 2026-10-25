//
//  IRSignature.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 08/10/2018.
//

#import "EDSignature.h"
#import "libed25519/ed25519_sha2.h"

@interface EDSignature()

@property(copy, nonatomic)NSData *rawData;

@end

@implementation EDSignature

+ (NSUInteger)length {
    return 64;
}

- (nullable instancetype)initWithRawData:(nonnull NSData *)data error:(NSError*_Nullable*_Nullable)error {
    if (data.length != [[self class] length]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Raw signature size must be %@ but %@ received",
                                 @([[self class] length]), @(data.length)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRSignatureErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    self = [super init];

    if (self) {
        self.rawData = data;
    }

    return self;
}

@end
