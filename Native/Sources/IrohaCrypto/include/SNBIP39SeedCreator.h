//
//  SNBIP39SeedCreator.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 26.06.2020.
//

#import <Foundation/Foundation.h>

@protocol SNBIP39SeedCreatorProtocol <NSObject>

- (nullable NSData*)deriveSeedFrom:(nonnull NSData*)entropy
                        passphrase:(nonnull NSString*)passphrase
                             error:(NSError*_Nullable*_Nullable)error;

@end

@interface SNBIP39SeedCreator : NSObject<SNBIP39SeedCreatorProtocol>

@end
