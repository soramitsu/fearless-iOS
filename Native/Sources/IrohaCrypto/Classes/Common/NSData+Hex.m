//
//  NSData+Hex.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23/10/2018.
//

#import "NSData+Hex.h"

@implementation NSData (Hex)

- (nullable instancetype)initWithHexString:(nonnull NSString*)hexString error:(NSError*_Nullable*_Nullable)error {
    NSUInteger length = [hexString length];

    if (length % 2 != 0) {
        if (error) {
            NSString *message = @"String length must be even";
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRHexDataInvalidHexString
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    NSMutableCharacterSet *characterSet = [NSMutableCharacterSet characterSetWithCharactersInString:@"abcdefABCDEF"];
    [characterSet formUnionWithCharacterSet:[NSCharacterSet decimalDigitCharacterSet]];
    [characterSet invert];

    if ([hexString rangeOfCharacterFromSet:characterSet].location != NSNotFound) {
        if (error) {
            NSString *message = @"String contains invalid characters";
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRHexDataInvalidHexString
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    NSMutableData *resultData = [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};

    for (int i = 0; i < ([hexString length] / 2); i++) {
        byte_chars[0] = [hexString characterAtIndex:i * 2];
        byte_chars[1] = [hexString characterAtIndex:i * 2 + 1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [resultData appendBytes:&whole_byte length:1];
    }

    return resultData;
}

- (nonnull NSString*)toHexString {
    unsigned char hex_str[]= "0123456789abcdef";
    NSUInteger length = [self length];

    char *cString = malloc(sizeof(char) * 2 * length + 1);

    uint8_t *bytes = (uint8_t*)[self bytes];

    for (int index = 0; index < length; index++) {
        cString[index * 2 + 0] = hex_str[(bytes[index] >> 4) & 0x0F];
        cString[index * 2 + 1] = hex_str[(bytes[index]) & 0x0F];
    }

    cString[2*length] = '\0';

    NSString *result = [[NSString alloc] initWithCString:cString encoding:NSASCIIStringEncoding];

    free(cString);

    return result;
}

@end
