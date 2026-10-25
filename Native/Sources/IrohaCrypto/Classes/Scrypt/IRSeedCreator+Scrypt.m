//
//  IRSeedCreator+Scrypt.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 27.02.2020.
//

#import "IRSeedCreator+Scrypt.h"
#import "IRScryptKeyDeriviation.h"

@implementation IRSeedCreator (Scrypt)

+ (nonnull instancetype)scrypt {
    id<IRMnemonicCreatorProtocol> mnemonicCreator = [[IRMnemonicCreator alloc] initWithLanguage:IREnglish];
    id<IRKeyDeriviationFunction> scrypt = [[IRScryptKeyDeriviation alloc] init];

    return [[IRSeedCreator alloc] initWithMnemonicCreator:mnemonicCreator
                                           keyDeriviation:scrypt];
}

@end
