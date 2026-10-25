#import <Foundation/Foundation.h>
#import <sr25519lib/sr25519.h>

#import "SNKeyFactory.h"
#import "SNKeypair.h"
#import "SNSigner.h"
#import "SNSignatureVerifier.h"

int main(void) {
    @autoreleasepool {
        uint8_t seedBytes[32];
        for (size_t index = 0; index < sizeof(seedBytes); index++) seedBytes[index] = (uint8_t)index;
        NSData *seed = [NSData dataWithBytes:seedBytes length:sizeof(seedBytes)];
        NSError *error = nil;
        id<SNKeypairProtocol> keypair = [[SNKeyFactory new] createKeypairFromSeed:seed error:&error];
        if (!keypair || error) return 1;

        NSData *message = [@"SR25519 signer boundary" dataUsingEncoding:NSUTF8StringEncoding];
        SNSigner *signer = [[SNSigner alloc] initWithKeypair:keypair];
        SNSignature *signature = [signer sign:message error:&error];
        if (!signature || error ||
            ![[SNSignatureVerifier new] verify:signature
                                 forOriginalData:message
                                  usingPublicKey:keypair.publicKey]) return 2;

        NSData *badSecretBytes = [NSData dataWithBytes:(uint8_t[64]){[0 ... 63] = 0xff} length:64];
        SNPrivateKey *badSecret = [[SNPrivateKey alloc] initWithRawData:badSecretBytes error:&error];
        if (!badSecret || error) return 3;
        SNSigner *badSecretSigner = [[SNSigner alloc] initWithKeypair:
            [[SNKeypair alloc] initWithPrivateKey:badSecret publicKey:keypair.publicKey]];
        if ([badSecretSigner sign:message error:&error] ||
            ![error.domain isEqualToString:@"SNSigner"] ||
            error.code != Sr25519SignInvalidSecret) return 4;

        error = nil;
        NSData *badPublicBytes = [NSData dataWithBytes:(uint8_t[32]){[0 ... 31] = 0xff} length:32];
        SNPublicKey *badPublic = [[SNPublicKey alloc] initWithRawData:badPublicBytes error:&error];
        if (!badPublic || error) return 5;
        SNSigner *badPublicSigner = [[SNSigner alloc] initWithKeypair:
            [[SNKeypair alloc] initWithPrivateKey:keypair.privateKey publicKey:badPublic]];
        if ([badPublicSigner sign:message error:&error] ||
            ![error.domain isEqualToString:@"SNSigner"] ||
            error.code != Sr25519SignInvalidPublic) return 6;

        puts("ObjC signer: valid signature verified; malformed secret/public returned errors");
        return 0;
    }
}
