//
//  IRSeedCreator.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 16/11/2018.
//

#import "IRSeedCreator.h"

static NSString* const WORDS_SEPARATOR = @" ";

@interface IRSeedCreator()

@property(strong, nonatomic)id<IRMnemonicCreatorProtocol> mnemonicCreator;
@property(strong, nonatomic)id<IRKeyDeriviationFunction> keyDeriviation;

@end

@implementation IRSeedCreator

#pragma mark - Initialize

- (nonnull instancetype)initWithMnemonicCreator:(nonnull id<IRMnemonicCreatorProtocol>)mnemonicCreator
                                 keyDeriviation:(nonnull id<IRKeyDeriviationFunction>)keyDeriviation {
    if (self = [super init]) {
        _mnemonicCreator = mnemonicCreator;
        _keyDeriviation = keyDeriviation;
    }

    return self;
}

#pragma mark - IRSeedCreatorProtocol

- (nullable NSData*)randomSeedWithMnemonicStrength:(IRMnemonicStrength)strength
                                          password:(nonnull NSString*)password
                                           project:(nonnull NSString*)project
                                           purpose:(nonnull NSString*)purpose
                                            length:(NSUInteger)seedLength
                                    resultMnemonic:(id<IRMnemonicProtocol> _Nullable * _Nonnull)mnemonic
                                             error:(NSError*_Nullable*_Nullable)error {
    NSData* saltData = [IRSeedCreator createSaltFromPassword:password
                                                     project:project
                                                     purpose:purpose
                                                       error:error];

    if (!saltData) {
        return nil;
    }

    return [self randomSeedWithMnemonicStrength:strength
                                           salt:saltData
                                         length:seedLength
                                 resultMnemonic:mnemonic
                                          error:error];
}

- (nullable NSData*)randomSeedWithMnemonicStrength:(IRMnemonicStrength)strength
                                              salt:(nonnull NSData*)salt
                                            length:(NSUInteger)seedLength
                                    resultMnemonic:(id<IRMnemonicProtocol> _Nullable * _Nonnull)mnemonic
                                             error:(NSError*_Nullable*_Nullable)error {
    *mnemonic = [_mnemonicCreator randomMnemonic:strength error:error];

    if (!(*mnemonic)) {
        return nil;
    }

    NSString* normalizedMnemonic = [[*mnemonic toString] decomposedStringWithCompatibilityMapping];

    return [_keyDeriviation deriveKeyFrom:[normalizedMnemonic dataUsingEncoding:NSUTF8StringEncoding]
                                     salt:salt
                                   length:seedLength
                                    error:error];
}

- (nullable NSData*)deriveSeedFromMnemonicPhrase:(nonnull NSString*)mnemonicPhrase
                                        password:(nonnull NSString*)password
                                         project:(nonnull NSString*)project
                                         purpose:(nonnull NSString*)purpose
                                          length:(NSUInteger)seedLength
                                           error:(NSError*_Nullable*_Nullable)error {
    NSData* saltData = [IRSeedCreator createSaltFromPassword:password
                                                     project:project
                                                     purpose:purpose
                                                       error:error];

    if (!saltData) {
        return nil;
    }

    return [self deriveSeedFromMnemonicPhrase:mnemonicPhrase
                                         salt:saltData
                                       length:(NSUInteger)seedLength
                                        error:error];
}

- (nullable NSData*)deriveSeedFromMnemonicPhrase:(nonnull NSString*)mnemonicPhrase
                                            salt:(nonnull NSData*)salt
                                          length:(NSUInteger)seedLength
                                           error:(NSError*_Nullable*_Nullable)error {
    id<IRMnemonicProtocol> mnemonic = [_mnemonicCreator mnemonicFromList:mnemonicPhrase
                                                                   error:error];

    if (!mnemonic) {
        return nil;
    }

    NSString* normalizedMnemonic = [[mnemonic toString] decomposedStringWithCompatibilityMapping];

    return [_keyDeriviation deriveKeyFrom:[normalizedMnemonic dataUsingEncoding:NSUTF8StringEncoding]
                                     salt:salt
                                   length:seedLength
                                    error:error];
}

+ (nullable NSData*)createSaltFromPassword:(nonnull NSString*)password
                                   project:(nonnull NSString*)project
                                   purpose:(nonnull NSString*)purpose
                                     error:(NSError*_Nullable*_Nullable)error {
    NSString* normalizedSalt = [[NSString stringWithFormat:@"%@|%@|%@", project, purpose, password]
                                decomposedStringWithCompatibilityMapping];

    NSData* saltData = [normalizedSalt dataUsingEncoding:NSUTF8StringEncoding];

    if (!saltData) {
        if (error) {
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IREmptySalt
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unexpected nil salt"}];
        }
    }

    return saltData;
}

@end
