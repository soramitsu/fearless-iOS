//
//  IRBIP39KeyDeriviationFunction.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 27.02.2020.
//

#import <Foundation/Foundation.h>
#import "IRKeyDeriviationFunction.h"

typedef NS_ENUM(NSUInteger, IRBIP39KeyDeriviationError) {
    IRBIP39PBKDF2Failed
};

@interface IRBIP39KeyDeriviation : NSObject<IRKeyDeriviationFunction>

@end
