//
//  SNPrivateKey.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import "SNPrivateKey.h"
#import "sr25519lib/sr25519.h"

@interface SNPrivateKey()

@property(copy, nonatomic)NSData *rawData;

@end

@implementation SNPrivateKey

- (nullable instancetype)initWithRawData:(nonnull NSData *)data
                                   error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    if ([data length] != SR25519_SECRET_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Invalid raw data length %@ but expected %@",
                                 @([data length]), @(SR25519_SECRET_SIZE)];
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

- (nullable instancetype)initWithFromEd25519:(nonnull NSData*)data
                                       error:(NSError*_Nullable*_Nullable)error {
    if ([data length] != SR25519_SECRET_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Invalid raw data length %@ but expected %@",
                                 @([data length]), @(SR25519_SECRET_SIZE)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRCryptoKeyErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    if (self = [super init]) {
        uint8_t secret_out[SR25519_SECRET_SIZE];
        sr25519_from_ed25519_bytes(secret_out, data.bytes);

        self.rawData = [NSData dataWithBytes:secret_out length:SR25519_SECRET_SIZE];
    }

    return self;
}

- (nonnull NSData*)toEd25519Data {
    uint8_t secret_out[SR25519_SECRET_SIZE];
    sr25519_to_ed25519_bytes(secret_out, _rawData.bytes);

    return [NSData dataWithBytes:secret_out length:SR25519_SECRET_SIZE];
}

@end
