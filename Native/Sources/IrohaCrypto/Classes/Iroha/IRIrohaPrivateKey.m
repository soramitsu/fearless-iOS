//
//  IRPrivateKey.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 07/10/2018.
//

#import "IRIrohaPrivateKey.h"
#import "libed25519/ed25519.h"

@interface IRIrohaPrivateKey()

@property(copy, nonatomic)NSData *rawData;

@end

@implementation IRIrohaPrivateKey

- (nullable instancetype)initWithRawData:(NSData *)data
                                   error:(NSError*_Nullable*_Nullable)error {
    if (data.length != ed25519_privkey_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Raw key size must be %@ but %@ received",
                                 @(ed25519_privkey_SIZE), @(data.length)];
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
