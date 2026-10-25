//
//  IRPublicKey.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 07/10/2018.
//

#import "IRIrohaPublicKey.h"
#import "libed25519/ed25519.h"

@interface IRIrohaPublicKey()

@property(copy, nonatomic)NSData *rawData;

@end

@implementation IRIrohaPublicKey

- (nullable instancetype)initWithRawData:(NSData *)data
                                   error:(NSError*_Nullable*_Nullable)error {
    if (data.length != ed25519_pubkey_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Raw key size must be %@ but %@ received",
                                 @(ed25519_pubkey_SIZE), @(data.length)];
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
