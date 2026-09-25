#import "FearlessObjectiveCExceptionCatcher.h"

NSErrorDomain const FearlessObjectiveCExceptionErrorDomain =
    @"jp.co.soramitsu.fearlesswallet.objective-c-exception";

@implementation FearlessObjectiveCExceptionCatcher

+ (nullable id)performObjectRead:(FearlessObjectiveCObjectReadBlock)block
                     caughtError:(NSError * _Nullable * _Nullable)caughtError {
    if (caughtError != NULL) {
        *caughtError = nil;
    }

    @try {
        id value = block();

        // A nil Objective-C result is conventionally interpreted by Swift as
        // failure for NSError-imported methods. Use a private sentinel so a
        // legitimate nil stored value remains distinguishable from an
        // exception without manufacturing an error.
        return value ?: [NSNull null];
    } @catch (NSException *exception) {
        (void)exception;

        if (caughtError != NULL) {
            *caughtError = [NSError
                errorWithDomain:FearlessObjectiveCExceptionErrorDomain
                           code:FearlessObjectiveCExceptionErrorCodeRaised
                       userInfo:@{
                           NSLocalizedDescriptionKey:
                               @"A stored value could not be decoded safely."
                       }];
        }

        return nil;
    }
}

@end
