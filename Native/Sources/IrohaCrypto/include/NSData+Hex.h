//
//  NSData+Hex.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23/10/2018.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, IRHexDataError) {
    IRHexDataInvalidHexString
};

@interface NSData (Hex)

- (nullable instancetype)initWithHexString:(nonnull NSString*)hexString
                                     error:(NSError*_Nullable*_Nullable)error;

- (nonnull NSString*)toHexString;

@end
