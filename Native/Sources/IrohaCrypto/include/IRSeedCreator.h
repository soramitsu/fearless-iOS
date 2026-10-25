//
//  IRSeedCreator.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 16/11/2018.
//

#import <Foundation/Foundation.h>
#import "IRKeyDeriviationFunction.h"
#import "IRMnemonicCreator.h"

@protocol IRSeedCreatorProtocol <NSObject>

- (nullable NSData*)randomSeedWithMnemonicStrength:(IRMnemonicStrength)strength
                                          password:(nonnull NSString*)password
                                           project:(nonnull NSString*)project
                                           purpose:(nonnull NSString*)purpose
                                            length:(NSUInteger)seedLength
                                    resultMnemonic:(id<IRMnemonicProtocol> _Nullable * _Nonnull)mnemonic
                                             error:(NSError*_Nullable*_Nullable)error;

- (nullable NSData*)randomSeedWithMnemonicStrength:(IRMnemonicStrength)strength
                                              salt:(nonnull NSData*)salt
                                            length:(NSUInteger)seedLength
                                    resultMnemonic:(id<IRMnemonicProtocol> _Nullable * _Nonnull)mnemonic
                                             error:(NSError*_Nullable*_Nullable)error;

- (nullable NSData*)deriveSeedFromMnemonicPhrase:(nonnull NSString*)mnemonicPhrase
                                        password:(nonnull NSString*)password
                                         project:(nonnull NSString*)project
                                         purpose:(nonnull NSString*)purpose
                                          length:(NSUInteger)seedLength
                                           error:(NSError*_Nullable*_Nullable)error;

- (nullable NSData*)deriveSeedFromMnemonicPhrase:(nonnull NSString*)mnemonicPhrase
                                            salt:(nonnull NSData*)salt
                                          length:(NSUInteger)seedLength
                                           error:(NSError*_Nullable*_Nullable)error;

@end

typedef NS_ENUM(NSUInteger, IRSeedError) {
    IREmptySalt
};

@interface IRSeedCreator : NSObject<IRSeedCreatorProtocol>

- (nonnull instancetype)initWithMnemonicCreator:(nonnull id<IRMnemonicCreatorProtocol>)mnemonicCreator
                                 keyDeriviation:(nonnull id<IRKeyDeriviationFunction>)keyDeriviation;

@end
