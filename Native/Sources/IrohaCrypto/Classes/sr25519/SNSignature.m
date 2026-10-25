//
//  SNSignature.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import "SNSignature.h"
#import "sr25519lib/sr25519.h"

@interface SNSignature()

@property(copy, nonatomic)NSData *rawData;

@end

@implementation SNSignature

- (nullable instancetype)initWithRawData:(nonnull NSData *)data error:(NSError*_Nullable*_Nullable)error {
    if (data.length != SR25519_SIGNATURE_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Raw signature size must be %@ but %@ received",
                                 @(SR25519_SIGNATURE_SIZE), @(data.length)];
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
