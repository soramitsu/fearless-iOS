//
//  SNSigner.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import "SNSigner.h"
#import "sr25519lib/sr25519.h"

@interface SNSigner()

@property(strong, nonatomic)_Nonnull id<SNKeypairProtocol> keypair;

@end

@implementation SNSigner

- (nonnull instancetype)initWithKeypair:(id<SNKeypairProtocol> _Nonnull)keypair {
    if (self = [super init]) {
        self.keypair = keypair;
    }

    return self;
}

- (nullable SNSignature*)sign:(nonnull NSData*)originalData
                              error:(NSError*_Nullable*_Nullable)error {
    uint8_t signatureBytes[SR25519_SIGNATURE_SIZE];
    NSData *publicKeyData = _keypair.publicKey.rawData;
    NSData *privateKeyData = _keypair.privateKey.rawData;
    Sr25519SignResult result = sr25519_sign_checked(signatureBytes,
                                                    sizeof(signatureBytes),
                                                    publicKeyData.bytes,
                                                    publicKeyData.length,
                                                    privateKeyData.bytes,
                                                    privateKeyData.length,
                                                    originalData.bytes,
                                                    originalData.length);
    if (result != Sr25519SignOk) {
        if (error) {
            NSString *message;
            switch (result) {
                case Sr25519SignInvalidSecret:
                    message = @"Invalid SR25519 private key";
                    break;
                case Sr25519SignInvalidPublic:
                    message = @"Invalid SR25519 public key";
                    break;
                case Sr25519SignMismatchedKeypair:
                    message = @"SR25519 public and private keys do not match";
                    break;
                default:
                    message = @"Unable to sign with SR25519 keypair";
                    break;
            }
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:result
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return nil;
    }

    NSData *signatureData = [NSData dataWithBytes:signatureBytes length:SR25519_SIGNATURE_SIZE];

    return [[SNSignature alloc] initWithRawData:signatureData error:error];
}

@end
