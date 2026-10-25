//
//  IRBIP39SeedCreator.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 27.02.2020.
//

#import <Foundation/Foundation.h>

@protocol IRBIP39SeedCreatorProtocol <NSObject>

- (nullable NSData*)deriveSeedFrom:(nonnull NSString*)mnemonic
                        passphrase:(nonnull NSString*)passphrase
                             error:(NSError*_Nullable*_Nullable)error;

@end

/**
*  Implementation of https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
*/

@interface IRBIP39SeedCreator : NSObject<IRBIP39SeedCreatorProtocol>

@end
