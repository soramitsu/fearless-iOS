//
//  IRSignature.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 08/10/2018.
//

#import "IRIrohaSignature.h"
#import "libed25519/ed25519.h"

@interface IRIrohaSignature()

@property(copy, nonatomic)NSData *rawData;

@end

@implementation IRIrohaSignature

- (nullable instancetype)initWithRawData:(nonnull NSData *)data error:(NSError*_Nullable*_Nullable)error {
    if (data.length != ed25519_signature_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Raw signature size must be %@ but %@ received",
                                 @(ed25519_signature_SIZE), @(data.length)];
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
