//
//  Data+Base58.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 01.07.2020.
//

#import "NSData+Base58.h"

static const UniChar base58chars[] = {
    '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K', 'L', 'M', 'N', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'm', 'n',
    'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z'
};

static const int8_t base58map[] = {
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
    -1,  0,  1,  2,  3,  4,  5,  6,  7,  8, -1, -1, -1, -1, -1, -1,
    -1,  9, 10, 11, 12, 13, 14, 15, 16, -1, 17, 18, 19, 20, 21, -1,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, -1, -1, -1, -1, -1,
    -1, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, -1, 44, 45, 46,
    47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, -1, -1, -1, -1, -1
};

@implementation NSData (Base58)

- (nonnull instancetype)initWithBase58String:(nonnull NSString*)base58String {
    size_t i, z = 0;

    while (z < base58String.length && [base58String characterAtIndex:z] == *base58chars) z++; // count leading zeroes

    uint8_t buf[(base58String.length - z)*733/1000 + 1]; // log(58)/log(256), rounded up

    memset(buf, 0, sizeof(buf));

    for (i = z; i < base58String.length; i++) {
        UniChar c = [base58String characterAtIndex:i];

        if (c >= sizeof(base58map)/sizeof(*base58map) || base58map[c] == -1) break; // invalid base58 digit

        uint32_t carry = base58map[c];

        for (ssize_t j = sizeof(buf) - 1; j >= 0; j--) {
            carry += (uint32_t)buf[j]*58;
            buf[j] = carry & 0xff;
            carry >>= 8;
        }
    }

    i = 0;
    while (i < sizeof(buf) && buf[i] == 0) i++; // skip leading zeroes

    NSMutableData *d = [NSMutableData dataWithCapacity:z + sizeof(buf) - i];

    d.length = z;
    [d appendBytes:&buf[i] length:sizeof(buf) - i];
    memset(buf, 0, sizeof(buf));
    return d;
}

- (NSString*)toBase58 {
    size_t i, z = 0;

    size_t length = self.length;

    const uint8_t *bytes = [self bytes];

    while (z < length && bytes[z] == 0) z++; // count leading zeroes

    uint8_t buf[(length - z)*138/100 + 1]; // log(256)/log(58), rounded up

    memset(buf, 0, sizeof(buf));

    for (i = z; i < length; i++) {
        uint32_t carry = bytes[i];

        for (ssize_t j = sizeof(buf) - 1; j >= 0; j--) {
            carry += (uint32_t)buf[j] << 8;
            buf[j] = carry % 58;
            carry /= 58;
        }
    }

    i = 0;
    while (i < sizeof(buf) && buf[i] == 0) i++; // skip leading zeroes

    CFMutableStringRef s = CFStringCreateMutable(kCFAllocatorDefault, z + sizeof(buf) - i);

    while (z-- > 0) CFStringAppendCharacters(s, base58chars, 1);
    while (i < sizeof(buf)) CFStringAppendCharacters(s, &base58chars[buf[i++]], 1);

    memset(buf, 0, sizeof(buf));

    return CFBridgingRelease(s);
}

@end
