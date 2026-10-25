//
//  IRSeedCreator+BIP39.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 27.02.2020.
//

#import "IRSeedCreator+BIP39.h"
#import "IRBIP39KeyDeriviation.h"

@implementation IRSeedCreator (BIP39)

+ (nonnull instancetype)bip39 {
    id<IRMnemonicCreatorProtocol> mnemonicCreator = [[IRMnemonicCreator alloc] initWithLanguage:IREnglish];
    id<IRKeyDeriviationFunction> keyDeriviation = [[IRBIP39KeyDeriviation alloc] init];

    return [[IRSeedCreator alloc] initWithMnemonicCreator:mnemonicCreator keyDeriviation:keyDeriviation];
}

@end
