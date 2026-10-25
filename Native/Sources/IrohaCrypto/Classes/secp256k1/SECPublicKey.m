//
//  SECPublicKey.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 24.07.2020.
//

#import "SECPublicKey.h"
#import "secp256k1.h"
#import "IRCryptoKey.h"

@interface SECPublicKey()

@property(nonatomic, copy)NSData *rawData;

@end

@implementation SECPublicKey

+ (NSUInteger)length {
    return 33;
}

+ (NSUInteger)uncompressedLength {
    return 65;
}

- (nullable instancetype)initWithRawData:(nonnull NSData*)data error:(NSError*_Nullable*_Nullable)error {
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

    if (self = [super init]) {
        self.rawData = data;
    }

    return self;
}

- (nullable NSData*)uncompressed:(NSError*_Nullable*_Nullable)error {
    secp256k1_pubkey rawPublicKey;

    secp256k1_context *context = secp256k1_context_create(SECP256K1_CONTEXT_NONE);

    int status = secp256k1_ec_pubkey_parse(context, &rawPublicKey, _rawData.bytes, [_rawData length]);

    if (status == 0) {
        secp256k1_context_destroy(context);

        if (error) {
            NSString *message = [NSString stringWithFormat:@"Uncompressing unexpectedly failed"];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRCryptoKeyErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    size_t uncompressedLength = [SECPublicKey uncompressedLength];
    unsigned char uncompresedPubkey[uncompressedLength];

    secp256k1_ec_pubkey_serialize(context,
                                  uncompresedPubkey,
                                  &uncompressedLength,
                                  &rawPublicKey,
                                  SECP256K1_EC_UNCOMPRESSED);

    secp256k1_context_destroy(context);

    return [NSData dataWithBytes:uncompresedPubkey length:uncompressedLength];
}

@end
