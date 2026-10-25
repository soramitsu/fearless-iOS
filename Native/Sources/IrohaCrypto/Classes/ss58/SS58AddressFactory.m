//
//  SS58AddressFactory.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 01.07.2020.
//

#import "SS58AddressFactory.h"
#import "NSData+Blake2.h"
#import "NSData+Base58.h"

static NSString * const PREFIX = @"SS58PRE";
static const UInt8 CHECKSUM_LENGTH = 2;
static const UInt8 SIMPLE_ADDRESS_LENGTH = 35;
static const UInt8 FULL_ADDRESS_LENGTH = 36;
static const UInt8 ACCOUNT_ID_LENGTH = 32;

@implementation SS58AddressFactory

- (nullable NSString*)addressFromAccountId:(NSData* _Nonnull)accountId
                                      type:(UInt16)type
                                     error:(NSError*_Nullable*_Nullable)error {

    UInt16 ident = type & 0b0011111111111111;

    NSMutableData *addressData = [NSMutableData data];

    if (ident < 64) {
        [addressData appendData:[NSData dataWithBytes:&type length:1]];
    } else {
        UInt8 first = ((ident & 0b0000000011111100) >> 2) | 0b01000000;
        UInt8 second = (ident >> 8 | (ident & 0b0000000000000011) << 6);

        [addressData appendBytes:&first length:1];
        [addressData appendBytes:&second length:1];
    }

    if ([accountId length] != ACCOUNT_ID_LENGTH) {
        accountId = [accountId blake2b:ACCOUNT_ID_LENGTH error:error];

        if (!accountId) {
            return nil;
        }
    }

    [addressData appendData:accountId];

    NSMutableData *checksumData = [NSMutableData data];
    [checksumData appendData:[PREFIX dataUsingEncoding:NSUTF8StringEncoding]];
    [checksumData appendData:addressData];

    NSData *hashed = [checksumData blake2bWithError:error];

    if (!hashed) {
        return nil;
    }

    [addressData appendData:[hashed subdataWithRange:NSMakeRange(0, CHECKSUM_LENGTH)]];

    return [addressData toBase58];
}

- (UInt16) decodeTypeFromData:(NSData *)addressData {
    UInt8 prefix = ((UInt8*)addressData.bytes)[0];
    if (prefix < 64) {
        return (UInt16)prefix;
    } else {
        UInt8 second = ((UInt8*)addressData.bytes)[1];
        UInt8 lower = prefix << 2 | second >> 6;
        UInt8 upper = second & 0b00111111;
        return ((UInt16)lower) | (((UInt16)upper) << 8);
    }
}

- (nullable NSData*)accountIdFromAddress:(nonnull NSString*)address
                                    type:(UInt16)type
                                   error:(NSError*_Nullable*_Nullable)error {
    NSData *ss58Data = [[NSData alloc] initWithBase58String:address];

    if ([ss58Data length] != SIMPLE_ADDRESS_LENGTH && [ss58Data length] != FULL_ADDRESS_LENGTH) {
        if (error) {
            NSString *message = @"Only account id based addresses are supported";
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:SNAddressFactoryUnsupported
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        
        return nil;
    }

    NSRange checksumRange = NSMakeRange(ss58Data.length - CHECKSUM_LENGTH, CHECKSUM_LENGTH);
    NSData *expectedChecksum = [ss58Data subdataWithRange: checksumRange];
    NSData *addressData = [ss58Data subdataWithRange:NSMakeRange(0, checksumRange.location)];

    UInt16 addressType = [self decodeTypeFromData: addressData];

    if (addressType != type) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"%@ type expected but %@ received", @(type), @(addressType)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:SNAddressFactoryUnexpectedType
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    NSMutableData *checksumMessage = [NSMutableData data];
    [checksumMessage appendData:[PREFIX dataUsingEncoding:NSUTF8StringEncoding]];
    [checksumMessage appendData:addressData];

    NSData *checksum = [[checksumMessage blake2bWithError:error] subdataWithRange:NSMakeRange(0, CHECKSUM_LENGTH)];

    if (!checksum) {
        return nil;
    }

    if (![checksum isEqualToData:expectedChecksum]) {
        if (error) {
            NSString *message = @"Incorrect checksum";
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:SNAddressFactoryIncorrectChecksum
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }
    int shift = addressType > 63 ? 2 : 1;
    NSData *accountId = [addressData subdataWithRange:NSMakeRange(shift, ACCOUNT_ID_LENGTH)];

    return accountId;
}

- (nullable NSNumber*)typeFromAddress:(nonnull NSString*)address
                                error:(NSError*_Nullable*_Nullable)error {
    NSData *ss58Data = [[NSData alloc] initWithBase58String:address];

    if ([ss58Data length] != SIMPLE_ADDRESS_LENGTH && [ss58Data length] != FULL_ADDRESS_LENGTH) {
        if (error) {
            NSString *message = @"Only account id based addresses are supported";
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:SNAddressFactoryUnsupported
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    UInt16 type = [self decodeTypeFromData: ss58Data];

    return [NSNumber numberWithInt:type];
}

@end
