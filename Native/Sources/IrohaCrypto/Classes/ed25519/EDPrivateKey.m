//
//  IRPrivateKey.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 07/10/2018.
//

#import "EDPrivateKey_Private.h"
#import "libed25519/ed25519_sha2.h"
#import <CommonCrypto/CommonDigest.h>

static const char EDNoncePrefixDomain[] = "IrohaCrypto EDPrivateKey nonce prefix";

@interface EDPrivateKey() {
    unsigned char _noncePrefix[EDExpandedKeyLength - EDScalarLength];
    BOOL _hasNoncePrefix;
}

@property(copy, nonatomic)NSData *rawData;

@end

@implementation EDPrivateKey

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

- (nonnull instancetype)initWithExpandedKey:(const unsigned char *)expandedKey {
    self = [super init];

    if (self) {
        self.rawData = [NSData dataWithBytes:expandedKey length:EDScalarLength];
        memcpy(_noncePrefix, expandedKey + EDScalarLength, sizeof(_noncePrefix));
        _hasNoncePrefix = YES;
    }

    return self;
}

- (void)getExpandedKey:(unsigned char *)expandedKey {
    memcpy(expandedKey, self.rawData.bytes, EDScalarLength);

    if (_hasNoncePrefix) {
        memcpy(expandedKey + EDScalarLength, _noncePrefix, sizeof(_noncePrefix));
        return;
    }

    CC_SHA512_CTX context;
    unsigned char digest[CC_SHA512_DIGEST_LENGTH];

    CC_SHA512_Init(&context);
    CC_SHA512_Update(&context, EDNoncePrefixDomain, (CC_LONG)strlen(EDNoncePrefixDomain));
    CC_SHA512_Update(&context, expandedKey, EDScalarLength);
    CC_SHA512_Final(digest, &context);

    memcpy(expandedKey + EDScalarLength, digest, sizeof(_noncePrefix));

    EDWipe(&context, sizeof(context));
    EDWipe(digest, sizeof(digest));
}

- (void)dealloc {
    EDWipe(_noncePrefix, sizeof(_noncePrefix));
}

@end
