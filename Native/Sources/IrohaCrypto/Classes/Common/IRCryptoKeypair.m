//
//  IRCryptoKeypair.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 07/10/2018.
//

#import "IRCryptoKeypair.h"

@interface IRCryptoKeypair()

@property(strong, nonatomic)_Nonnull id<IRPublicKeyProtocol> publicKey;
@property(strong, nonatomic)_Nonnull id<IRPrivateKeyProtocol> privateKey;

@end


@implementation IRCryptoKeypair

- (nonnull instancetype)initPublicKey:(_Nonnull id<IRPublicKeyProtocol>)publicKey
                           privateKey:(_Nonnull id<IRPrivateKeyProtocol>)privateKey {
    self = [super init];

    if (self) {
        _publicKey = publicKey;
        _privateKey = privateKey;
    }

    return self;
}

@end
