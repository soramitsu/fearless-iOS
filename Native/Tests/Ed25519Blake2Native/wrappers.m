// Runs the IrohaCrypto Objective-C wrappers over Ed25519, BLAKE2 and SHA-3 one
// operation per input line, printing one result line, so the wrappers can be compared
// across the previous XCFramework archives and the vendored sources.

#import <Foundation/Foundation.h>
#import "EDKeyFactory.h"
#import "EDPrivateKey.h"
#import "EDPublicKey.h"
#import "EDSignature.h"
#import "EDSigner.h"
#import "EDSignatureVerifier.h"
#import "IRIrohaKeyFactory.h"
#import "IRIrohaPrivateKey.h"
#import "IRIrohaPublicKey.h"
#import "IRIrohaSignature.h"
#import "IRIrohaSigner.h"
#import "IRSignatureVerifier.h"
#import "IRMnemonicCreator.h"
#import "SNBIP39SeedCreator.h"
#import "NSData+Blake2.h"
#import "NSData+SHA3.h"

// A private key that is not an EDPrivateKey, as callers may pass any IRPrivateKeyProtocol.
@interface ForeignPrivateKey : NSObject<IRPrivateKeyProtocol>
@property(copy, nonatomic) NSData *rawData;
@end

@implementation ForeignPrivateKey
- (nullable instancetype)initWithRawData:(NSData *)data error:(NSError **)error {
    if (self = [super init]) {
        self.rawData = data;
    }
    return self;
}
@end

static NSData *Decode(NSString *hex) {
    if ([hex isEqualToString:@"-"]) {
        return [NSData data];
    }
    NSMutableData *data = [NSMutableData dataWithCapacity:hex.length / 2];
    for (NSUInteger i = 0; i + 1 < hex.length; i += 2) {
        unsigned int byte = 0;
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&byte];
        uint8_t value = (uint8_t)byte;
        [data appendBytes:&value length:1];
    }
    return data;
}

static NSString *Encode(NSData *data) {
    if (data == nil) {
        return @"nil";
    }
    if (data.length == 0) {
        return @"-";
    }
    NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 2];
    const uint8_t *bytes = data.bytes;
    for (NSUInteger i = 0; i < data.length; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    return hex;
}

// Substrate Ed25519 hard derivation: blake2b-256(SCALE("Ed25519HDKD") || seed || chaincode),
// with a junction string SCALE-encoded and zero-padded to 32 bytes.
static NSData *HardDerive(NSData *seed, NSString *junction) {
    NSData *name = [junction dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *chaincode = [NSMutableData data];
    uint8_t length = (uint8_t)(name.length << 2);
    [chaincode appendBytes:&length length:1];
    [chaincode appendData:name];
    chaincode.length = 32;
    NSMutableData *input = [NSMutableData data];
    uint8_t prefixLength = 11 << 2;
    [input appendBytes:&prefixLength length:1];
    [input appendData:[@"Ed25519HDKD" dataUsingEncoding:NSUTF8StringEncoding]];
    [input appendData:seed];
    [input appendData:chaincode];
    return [input blake2b:32 error:nil];
}

static NSString *Run(NSArray<NSString *> *token) {
    NSString *op = token[0];
    NSError *error = nil;
    if ([op isEqualToString:@"ed_seed"]) {
        id<IRCryptoKeypairProtocol> pair = [[EDKeyFactory new] deriveFromSeed:Decode(token[1]) error:&error];
        return [NSString stringWithFormat:@"%@ %@", Encode(pair.publicKey.rawData), Encode(pair.privateKey.rawData)];
    }
    if ([op isEqualToString:@"ed_from_private"]) {
        EDPrivateKey *key = [[EDPrivateKey alloc] initWithRawData:Decode(token[1]) error:&error];
        id<IRCryptoKeypairProtocol> pair = [[EDKeyFactory new] deriveFromPrivateKey:key error:&error];
        return Encode(pair.publicKey.rawData);
    }
    if ([op isEqualToString:@"ed_verify"]) {
        EDSignature *signature = [[EDSignature alloc] initWithRawData:Decode(token[1]) error:&error];
        EDPublicKey *key = [[EDPublicKey alloc] initWithRawData:Decode(token[3]) error:&error];
        BOOL valid = [[EDSignatureVerifier new] verify:signature forOriginalData:Decode(token[2]) usingPublicKey:key];
        return valid ? @"1" : @"0";
    }
    if ([op isEqualToString:@"ed_seed_sign"]) {
        // The wallet path: the private key from EDKeyFactory goes straight to EDSigner.
        id<IRCryptoKeypairProtocol> pair = [[EDKeyFactory new] deriveFromSeed:Decode(token[1]) error:&error];
        id<IRSignatureProtocol> signature = [[[EDSigner alloc] initWithPrivateKey:pair.privateKey] sign:Decode(token[2]) error:&error];
        return Encode(signature.rawData);
    }
    if ([op isEqualToString:@"ed_scalar_sign"] || [op isEqualToString:@"ed_foreign_sign"]) {
        id<IRPrivateKeyProtocol> key = [op isEqualToString:@"ed_scalar_sign"]
            ? [[EDPrivateKey alloc] initWithRawData:Decode(token[1]) error:&error]
            : [[ForeignPrivateKey alloc] initWithRawData:Decode(token[1]) error:&error];
        id<IRSignatureProtocol> signature = [[[EDSigner alloc] initWithPrivateKey:key] sign:Decode(token[2]) error:&error];
        return Encode(signature.rawData);
    }
    if ([op isEqualToString:@"ed_sign_verifies"]) {
        EDPrivateKey *key = [[EDPrivateKey alloc] initWithRawData:Decode(token[1]) error:&error];
        id<IRCryptoKeypairProtocol> pair = [[EDKeyFactory new] deriveFromPrivateKey:key error:&error];
        NSData *message = Decode(token[2]);
        id<IRSignatureProtocol> signature = [[[EDSigner alloc] initWithPrivateKey:key] sign:message error:&error];
        BOOL valid = [[EDSignatureVerifier new] verify:signature forOriginalData:message usingPublicKey:pair.publicKey];
        return valid ? @"1" : @"0";
    }
    if ([op isEqualToString:@"ir_from_private"]) {
        IRIrohaPrivateKey *key = [[IRIrohaPrivateKey alloc] initWithRawData:Decode(token[1]) error:&error];
        id<IRCryptoKeypairProtocol> pair = [[IRIrohaKeyFactory new] deriveFromPrivateKey:key error:&error];
        return Encode(pair.publicKey.rawData);
    }
    if ([op isEqualToString:@"ir_sign"]) {
        IRIrohaPrivateKey *key = [[IRIrohaPrivateKey alloc] initWithRawData:Decode(token[1]) error:&error];
        id<IRSignatureProtocol> signature = [[[IRIrohaSigner alloc] initWithPrivateKey:key] sign:Decode(token[2]) error:&error];
        return Encode(signature.rawData);
    }
    if ([op isEqualToString:@"ir_verify"]) {
        IRIrohaSignature *signature = [[IRIrohaSignature alloc] initWithRawData:Decode(token[1]) error:&error];
        IRIrohaPublicKey *key = [[IRIrohaPublicKey alloc] initWithRawData:Decode(token[3]) error:&error];
        BOOL valid = [[IRIrohaSignatureVerifier new] verify:signature forOriginalData:Decode(token[2]) usingPublicKey:key];
        return valid ? @"1" : @"0";
    }
    if ([op isEqualToString:@"blake2b"] || [op isEqualToString:@"blake2s"]) {
        NSUInteger length = (NSUInteger)token[1].integerValue;
        NSData *message = Decode(token[2]);
        NSData *digest = [op isEqualToString:@"blake2b"] ? [message blake2b:length error:&error]
                                                         : [message blake2s:length error:&error];
        return Encode(digest);
    }
    if ([op isEqualToString:@"sha3_256"] || [op isEqualToString:@"sha3_512"]) {
        IRSha3Variant variant = [op isEqualToString:@"sha3_256"] ? IRSha3Variant256 : IRSha3Variant512;
        return Encode([Decode(token[1]) sha3:variant error:&error]);
    }
    if ([op isEqualToString:@"substrate_ed"]) {
        NSString *phrase = [[NSString alloc] initWithData:Decode(token[1]) encoding:NSUTF8StringEncoding];
        id<IRMnemonicProtocol> mnemonic = [[IRMnemonicCreator defaultCreator] mnemonicFromList:phrase error:&error];
        NSData *seed = [[SNBIP39SeedCreator new] deriveSeedFrom:mnemonic.entropy passphrase:@"" error:&error];
        NSData *mini = [seed subdataWithRange:NSMakeRange(0, 32)];
        NSString *junction = [[NSString alloc] initWithData:Decode(token[2]) encoding:NSUTF8StringEncoding];
        NSData *derived = HardDerive(mini, junction);
        id<IRCryptoKeypairProtocol> pair = [[EDKeyFactory new] deriveFromSeed:derived error:&error];
        return [NSString stringWithFormat:@"%@ %@ %@", Encode(mini), Encode(derived), Encode(pair.publicKey.rawData)];
    }
    fprintf(stderr, "unknown operation: %s\n", op.UTF8String);
    exit(2);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: %s operations.txt\n", argv[0]);
            return 2;
        }
        NSString *text = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:nil];
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            if (line.length == 0) {
                continue;
            }
            @autoreleasepool {
                printf("%s\n", Run([line componentsSeparatedByString:@" "]).UTF8String);
            }
        }
    }
    return 0;
}
