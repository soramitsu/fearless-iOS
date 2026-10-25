//
//  SNKeypair.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 25.06.2020.
//

#import "SNKeypair.h"
#import "sr25519lib/sr25519.h"

@interface SNKeypair()

@property(strong, nonatomic)SNPrivateKey *privateKey;
@property(strong, nonatomic)SNPublicKey *publicKey;

@end

@implementation SNKeypair

- (nonnull instancetype)initWithPrivateKey:(nonnull SNPrivateKey*)privateKey
                                 publicKey:(nonnull SNPublicKey*)publicKey {
    if (self = [super init]) {
        self.privateKey = privateKey;
        self.publicKey = publicKey;
    }

    return self;
}

- (nullable instancetype)initWithRawData:(nonnull NSData*)rawData error:(NSError*_Nullable*_Nullable)error {
    if ([rawData length] != SR25519_KEYPAIR_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Invalid keypair length %@ but expected %@",
                                 @([rawData length]), @(SR25519_KEYPAIR_SIZE)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:SNKeypairErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    if (self = [super init]) {
        NSData *privateKeyData = [rawData subdataWithRange:NSMakeRange(0, SR25519_SECRET_SIZE)];
        SNPrivateKey *privateKey = [[SNPrivateKey alloc] initWithRawData:privateKeyData
                                                                   error:error];

        if (!privateKey) {
            return nil;
        }

        NSData *publicKeyData = [rawData subdataWithRange:NSMakeRange(SR25519_SECRET_SIZE, SR25519_PUBLIC_SIZE)];
        SNPublicKey *publicKey = [[SNPublicKey alloc] initWithRawData:publicKeyData
                                                                error:error];

        if (!publicKey) {
            return nil;
        }

        self.privateKey = privateKey;
        self.publicKey = publicKey;
    }

    return self;
}

- (nonnull NSData*)rawData {
    NSMutableData *result = [NSMutableData dataWithData:_privateKey.rawData];
    [result appendData:_publicKey.rawData];
    return result;
}

@end
