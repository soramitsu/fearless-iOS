//
//  Data+Base58.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 01.07.2020.
//

#import <Foundation/Foundation.h>

@interface NSData (Base58)

- (nonnull instancetype)initWithBase58String:(nonnull NSString*)base58String;

- (nonnull NSString*)toBase58;

@end
