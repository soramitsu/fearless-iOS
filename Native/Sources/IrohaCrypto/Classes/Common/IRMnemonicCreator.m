//
//  IRMnemonic.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 15/11/2018.
//

#import "IRMnemonicCreator.h"
#import <CommonCrypto/CommonCrypto.h>
#import "IRWordList.h"

static const unsigned char BITS_PER_BYTE = 8;
static const unsigned char STRENGTH_STEP = 32;
static const unsigned char BITS_PER_WORD = 11;

@interface IRMnemonic: NSObject<IRMnemonicProtocol>

- (nullable instancetype)initWithWords:(nonnull NSArray<NSString*>*)words andEntropy:(nonnull NSData*)entropy;

@property(strong, nonatomic)NSArray<NSString*>* _Nonnull words;
@property(strong, nonatomic)NSData* _Nonnull entropy;

@end

@implementation IRMnemonicCreator

#pragma mark - Initialization

+ (instancetype)defaultCreator {
    return [[IRMnemonicCreator alloc] initWithLanguage:IREnglish];
}

- (nonnull instancetype)initWithLanguage:(IRMnemonicLanguage)language {
    if (self = [super init]) {
        _language = language;
    }

    return self;
}

#pragma mark - IRMnemonicCreatorProtocol

- (nullable id<IRMnemonicProtocol>)randomMnemonic:(IRMnemonicStrength)strength
                                            error:(NSError*_Nullable*_Nullable)error {
    NSUInteger bytesCount = strength / BITS_PER_BYTE;
    NSMutableData *entropy = [NSMutableData dataWithLength:bytesCount];

    int status = SecRandomCopyBytes(kSecRandomDefault, entropy.length, entropy.mutableBytes);

    if (status != errSecSuccess) {
        if (error) {
            *error = [[self class] errorWithMessage:[NSString stringWithFormat:@"Can't generate %@ random bytes", @(bytesCount)]
                                                         code:IRRandomGenerationFailed];
        }

        return nil;
    }

    return [self mnemonicFromEntropy:entropy error:error];
}

- (nullable id<IRMnemonicProtocol>)mnemonicFromEntropy:(nonnull NSData*)entropy
                                                 error:(NSError*_Nullable*_Nullable)error {
    NSUInteger entropyLength = entropy.length;

    if (![[self class] isValidEntropyLength:entropyLength]) {
        if (error) {
            *error = [[self class] errorWithMessage:[NSString stringWithFormat:@"Invalid entropy length %@", @(entropyLength)]
                                                         code:IRInvalidEntropyLength];
        }

        return nil;
    }

    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(entropy.bytes, (CC_LONG)entropyLength, hash.mutableBytes);

    NSMutableData *tmpData = [NSMutableData dataWithData:entropy];
    [tmpData appendData:hash];

    unsigned char* tmpBytes = (unsigned char*)(tmpData.bytes);

    NSMutableArray<NSString*>* mnemonicWords = [NSMutableArray array];
    NSArray<NSString*>* vocabulary = [[self class] vocabularyForLanguage:_language];
    NSUInteger wordsCount = [[self class] wordsCountForEntropyLength:entropyLength];

    for(NSUInteger wordIndex = 0; wordIndex < wordsCount; wordIndex++) {
        NSUInteger vocabularyIndex = 0;

        for(NSUInteger bitPosition = wordIndex * BITS_PER_WORD; bitPosition < (wordIndex + 1) * BITS_PER_WORD; bitPosition++) {
            unsigned char positionByte = tmpBytes[bitPosition / BITS_PER_BYTE];
            unsigned char mask = 1 << (BITS_PER_BYTE - (bitPosition % BITS_PER_BYTE) - 1);

            vocabularyIndex = (vocabularyIndex << 1) | !!(positionByte & mask);
        }

        [mnemonicWords addObject:vocabulary[vocabularyIndex]];
    }

    return [[IRMnemonic alloc] initWithWords:mnemonicWords andEntropy:entropy];
}

- (nullable id<IRMnemonicProtocol>)mnemonicFromList:(nonnull NSString *)mnemonicPhrase
                                              error:(NSError*_Nullable*_Nullable)error {
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
    NSArray *wordList = [mnemonicPhrase componentsSeparatedByCharactersInSet:whitespace];
    NSUInteger wordsCount = wordList.count;
    if (![[self class] isValidWordsCount:wordsCount]) {
        if (error) {
            *error = [[self class] errorWithMessage:[NSString stringWithFormat:@"Invalid number of words %@ in word list", @(wordsCount)]
                                                         code:IRInvalidNumberOfWords];
        }

        return nil;
    }

    NSUInteger entropyLength = [[self class] entropyLengthFromWordsCount:wordsCount];
    NSUInteger numberOfChecksumBits = [[self class] checksumSizeForEntropyLength:entropyLength];
    unsigned char entropyWithChecksumBytes[entropyLength + numberOfChecksumBits / BITS_PER_BYTE + 1];

    NSArray<NSString*>* vocabulary = [[self class] vocabularyForLanguage:_language];

    for(NSUInteger wordIndex = 0; wordIndex < wordsCount; wordIndex++) {
        NSUInteger vocabularyIndex = [vocabulary indexOfObject:wordList[wordIndex]];

        if (vocabularyIndex == NSNotFound) {
            if (error) {
                *error = [[self class] errorWithMessage:[NSString stringWithFormat:@"Word %@ not found in language %@", wordList[wordIndex], @(_language)]
                                                             code:IRWordNotFound];
            }

            return nil;
        }

        for(NSUInteger bitPosition = wordIndex * BITS_PER_WORD; bitPosition < (wordIndex + 1) * BITS_PER_WORD; bitPosition++) {
            NSUInteger wordMask = 1 << (BITS_PER_WORD - (bitPosition % BITS_PER_WORD) - 1);
            unsigned char entropyMask = 1 << (BITS_PER_BYTE - (bitPosition % BITS_PER_BYTE) - 1);

            unsigned char entropyByte = entropyWithChecksumBytes[bitPosition / BITS_PER_BYTE];

            if ((vocabularyIndex & wordMask) != 0) {
                entropyByte |= entropyMask;
            } else {
                entropyByte &= ~entropyMask;
            }

            entropyWithChecksumBytes[bitPosition / BITS_PER_BYTE] = entropyByte;
        }
    }

    BOOL isValidChecksum = [[self class] validateChecksumForEntropy:entropyWithChecksumBytes
                                                                entropyLength:entropyLength
                                                                checksumBytes:&entropyWithChecksumBytes[entropyLength]];

    if (!isValidChecksum) {
        if (error) {
            *error = [[self class] errorWithMessage:[NSString stringWithFormat:@"Entropy data not matching checksum"]
                                                         code:IRChecksumFailed];
        }

        return nil;
    }

    NSData *entropy = [NSData dataWithBytes:entropyWithChecksumBytes length:entropyLength];

    return [[IRMnemonic alloc] initWithWords:wordList andEntropy:entropy];
}

#pragma mark - Helpers

+ (BOOL)isValidWordsCount:(NSUInteger)count {
    return ((count * STRENGTH_STEP * BITS_PER_WORD) % ((STRENGTH_STEP + 1) * BITS_PER_BYTE)) == 0;
}

+ (BOOL)isValidEntropyLength:(NSUInteger)length {
    NSUInteger bits = length * BITS_PER_BYTE;
    return (bits >= IREntropy128 && bits <= IREntropy320) && (bits % STRENGTH_STEP == 0);
}

+ (NSUInteger)wordsCountForEntropyLength:(NSUInteger)length {
    NSUInteger bits = length * BITS_PER_BYTE;
    NSUInteger checksumSize = bits / STRENGTH_STEP;
    return (bits + checksumSize) / BITS_PER_WORD;
}

+ (NSUInteger)entropyLengthFromWordsCount:(NSUInteger)count {
    NSUInteger bits = (count * STRENGTH_STEP * BITS_PER_WORD) / (STRENGTH_STEP + 1);
    return bits / BITS_PER_BYTE;
}

+ (NSUInteger)checksumSizeForEntropyLength:(NSUInteger)length {
    return length * BITS_PER_BYTE / STRENGTH_STEP;
}

+ (NSArray<NSString*>*)vocabularyForLanguage:(IRMnemonicLanguage)language {
    return [NSArray arrayWithObjects:ENGLISH_WORDS count:VOCABULARY_LENGTH];
}

+ (BOOL)validateChecksumForEntropy:(unsigned char*)entropyBytes entropyLength:(NSUInteger)entropyLength checksumBytes:(unsigned char*)checksumBytes {
    NSMutableData *hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(entropyBytes, (CC_LONG)entropyLength, hash.mutableBytes);

    unsigned char* hashBytes = (unsigned char*)(hash.bytes);

    NSUInteger checksumSizeInBits = [[self class] checksumSizeForEntropyLength:entropyLength];

    for(NSUInteger bitIndex = 0; bitIndex < checksumSizeInBits; bitIndex++) {
        unsigned char hashByte = hashBytes[bitIndex / BITS_PER_BYTE];
        unsigned char checksumByte = checksumBytes[bitIndex / BITS_PER_BYTE];
        unsigned char mask = 1 << (BITS_PER_BYTE - (bitIndex % BITS_PER_BYTE) - 1);

        BOOL sameBit = (!!(hashByte & mask)) == (!!(checksumByte & mask));

        if (!sameBit) {
            return NO;
        }
    }

    return YES;
}

+ (nonnull NSError*)errorWithMessage:(nonnull NSString*)message code:(NSUInteger)code {
    return [NSError errorWithDomain:NSStringFromClass([self class])
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end

@implementation IRMnemonic

- (nullable instancetype)initWithWords:(nonnull NSArray<NSString*>*)words andEntropy:(nonnull NSData*)entropy {
    if (self = [super init]) {
        _words = [words copy];
        _entropy = [entropy copy];
    }

    return self;
}

#pragma mark - IRMnemonicProtocol

- (nonnull NSData*)entropy {
    return _entropy;
}

- (nonnull NSString*)wordAtIndex:(NSUInteger)index {
    return _words[index];
}

- (NSUInteger)numberOfWords {
    return _words.count;
}

- (nonnull NSArray<NSString*>*)allWords {
    return _words;
}

- (nonnull NSString *)toString {
    return [_words componentsJoinedByString:@" "];
}

@end
