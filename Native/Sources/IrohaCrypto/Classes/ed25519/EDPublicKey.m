//
//  IRPublicKey.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 07/10/2018.
//

#import "EDPublicKey.h"
#import "libed25519/ed25519_sha2.h"

@interface EDPublicKey()

@property(copy, nonatomic)NSData *rawData;

@end

@implementation EDPublicKey

+ (NSUInteger)length {
    return 32;
}

- (nullable instancetype)initWithRawData:(NSData *)data
                                   error:(NSError*_Nullable*_Nullable)error {
    if (data.length != [[self class] length]) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Raw key size must be %@ but %@ received",
                                 @([[self class] length]), @(data.length)];
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
