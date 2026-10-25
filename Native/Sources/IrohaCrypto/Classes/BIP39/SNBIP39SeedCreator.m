//
//  SNBIP39SeedCreator.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 26.06.2020.
//

#import "SNBIP39SeedCreator.h"
#import "IRBIP39KeyDeriviation.h"

static NSString* const PASSPHRASE_PREFIX = @"mnemonic";
static const NSUInteger SEED_LENGTH = 64;

@interface SNBIP39SeedCreator()

@property(strong, nonatomic)id<IRKeyDeriviationFunction> keyDeriviation;

@end

@implementation SNBIP39SeedCreator

#pragma mark - Initialize

- (nonnull instancetype)init {
    if (self = [super init]) {
        _keyDeriviation = [[IRBIP39KeyDeriviation alloc] init];
    }

    return self;
}

#pragma mark - SNBIP39SeedCreatorProtocol

- (nullable NSData*)deriveSeedFrom:(nonnull NSData*)entropy
                        passphrase:(nonnull NSString*)passphrase
                             error:(NSError*_Nullable*_Nullable)error {
    NSString *normalizedPassphrase = [[PASSPHRASE_PREFIX stringByAppendingString:passphrase] decomposedStringWithCompatibilityMapping];
    NSData *salt = [normalizedPassphrase dataUsingEncoding:NSUTF8StringEncoding];

    return [_keyDeriviation deriveKeyFrom:entropy
                                     salt:salt
                                   length:SEED_LENGTH
                                    error:error];
}


@end
