#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const FearlessObjectiveCExceptionErrorDomain;

typedef NS_ERROR_ENUM(
    FearlessObjectiveCExceptionErrorDomain,
    FearlessObjectiveCExceptionErrorCode
) {
    FearlessObjectiveCExceptionErrorCodeRaised = 1
};

typedef id _Nullable (^FearlessObjectiveCObjectReadBlock)(void);

/// Executes an Objective-C object read behind an exception boundary.
///
/// The returned error is intentionally generic. Exception names, reasons,
/// userInfo, call stacks, and the object payload must never cross this boundary.
@interface FearlessObjectiveCExceptionCatcher : NSObject

+ (nullable id)performObjectRead:(FearlessObjectiveCObjectReadBlock)block
                     caughtError:(NSError * _Nullable * _Nullable)caughtError;

@end

NS_ASSUME_NONNULL_END
