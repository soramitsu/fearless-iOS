//
//  IRBIP39SeedCreator.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 27.02.2020.
//

#import "IRBIP39SeedCreator.h"
#import "IRSeedCreator+BIP39.h"

static NSString* const PASSPHRASE_PREFIX = @"mnemonic";
static const NSUInteger SEED_LENGTH = 64;

@interface IRBIP39SeedCreator()

@property(nonatomic, strong)id<IRSeedCreatorProtocol> internalCreator;

@end

@implementation IRBIP39SeedCreator

#pragma mark - Initialize

- (nonnull instancetype)init {
    if (self = [super init]) {
        _internalCreator = [IRSeedCreator bip39];
    }

    return self;
}

#pragma mark - IRBIP39SeedCreatorProtocol

- (nullable NSData*)deriveSeedFrom:(nonnull NSString*)mnemonic
                        passphrase:(nonnull NSString*)passphrase
                             error:(NSError*_Nullable*_Nullable)error {
    NSString *normalizedPassphrase = [[PASSPHRASE_PREFIX stringByAppendingString:passphrase] decomposedStringWithCompatibilityMapping];
    NSData *salt = [normalizedPassphrase dataUsingEncoding:NSUTF8StringEncoding];

    return [_internalCreator deriveSeedFromMnemonicPhrase:mnemonic
                                                     salt:salt
                                                   length:SEED_LENGTH
                                                    error:error];
}

@end
