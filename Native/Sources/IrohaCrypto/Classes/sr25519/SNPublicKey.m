//
//  SNPublicKey.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import "SNPublicKey.h"
#import "sr25519lib/sr25519.h"

@interface SNPublicKey()

@property(copy, nonatomic)NSData *rawData;

@end

@implementation SNPublicKey

- (nullable instancetype)initWithRawData:(nonnull NSData*)data
                                   error:(NSError*_Nullable*_Nullable)error {
    if ([data length] != SR25519_PUBLIC_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Invalid raw data length %@ but expected %@",
                                 @([data length]), @(SR25519_PUBLIC_SIZE)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRCryptoKeyErrorInvalidRawData
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
