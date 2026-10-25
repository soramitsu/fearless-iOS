//
//  SNSigner.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import <Foundation/Foundation.h>
#import "SNKeypair.h"
#import "SNSignature.h"

@protocol SNSignerProtocol

- (nullable SNSignature*)sign:(nonnull NSData*)originalData
                        error:(NSError*_Nullable*_Nullable)error;

@end

@interface SNSigner : NSObject<SNSignerProtocol>

- (nonnull instancetype)initWithKeypair:(id<SNKeypairProtocol> _Nonnull)keypair;

@end
