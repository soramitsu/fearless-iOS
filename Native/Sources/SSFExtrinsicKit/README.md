# SSFExtrinsicKit

[![CI Status](https://img.shields.io/travis/Alex Lebedko/SSFExtrinsicKit.svg?style=flat)](https://travis-ci.org/Alex Lebedko/SSFExtrinsicKit)
[![Version](https://img.shields.io/cocoapods/v/SSFExtrinsicKit.svg?style=flat)](https://cocoapods.org/pods/SSFExtrinsicKit)
[![License](https://img.shields.io/cocoapods/l/SSFExtrinsicKit.svg?style=flat)](https://cocoapods.org/pods/SSFExtrinsicKit)
[![Platform](https://img.shields.io/cocoapods/p/SSFExtrinsicKit.svg?style=flat)](https://cocoapods.org/pods/SSFExtrinsicKit)

## Description

SSFExtrinsicKit provides ability to construct and submit extrinsic, estimate fee of transaction.

### Components - Interfaces

```
public protocol ExtrinsicServiceProtocol {
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    )

    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    )

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: TransactionSignerProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    )

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: TransactionSignerProtocol,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    )

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: TransactionSignerProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitAndWatchClosure
    )
}
```

```
public protocol ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics: Int
    )
        -> CompoundOperationWrapper<[FeeExtrinsicResult]>

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: TransactionSignerProtocol,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<[SubmitExtrinsicResult]>

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: TransactionSignerProtocol
    ) -> CompoundOperationWrapper<SubmitAndWatchExtrinsicResult>

    func createGenesisBlockHashOperation() -> BaseOperation<String>
}
```

### Components - classes

ExtrinsicOperationFactory - basic implementation of ExtrinsicOperationFactoryProtocol. It's used for create complete extrinsics from provided calls. ExtrinsicOperationFactory fetches metadata (nonce, era mortality, era information), make signature with provided signer, and make complete extrinsic with collected data.

ExtrinsicService - basic implementation of ExtrinsicServiceProtocol. It uses ExtrinsicOperationFactoryProtocol to create extrinsic and then submit it to network via provided websocket.

### Usage example

```
let extrinsicBuilderClosure = { builder in
    try builder.adding(call: #YOUR_RUNTIMECALLABLE_IMPL) 
}

let extrinsicService = ExtrinsicOperationFactory(accountId: #YOUR_ACCOUNT_ID, chainFormat: #SSFMODELS_ChainFormat, cryptoType: #SSFCrypto_CryptoType, runtimeRegistry: #SSFRuntimeCodingService_RuntimeCodingServiceProtocol, engine: #SSFChainConnection_ChainConnection, operationManager: #RobinHood_OperationManagerProtocol)

// Estimate fee
extrinsicService.estimateFee(extrinsicBuilderClosure, runningIn: .main, completion: { result in
    switch result {
        case let .success(runtimeDispatchInfo):
            print("Fee: \(runtimeDispatchInfo.fee)")
        case .failure:
            break
    }
}
})

//Submit extrinsic
        extrinsicService.submit(
            extrinsicBuilderClosure,
            signer: #SSFSigner_TransactionSignerProtocol,
            runningIn: .main
        ) { result in
            switch result:
            case let .success(transactionHash):
                print("Transaction hash: \(transactionHash)")
            case .failure:
                break
        }


```

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

SSFExtrinsicKit is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SSFExtrinsicKit'
```

## Author

Alex Lebedko, lebedko@soramitsu.co.jp

## License

SSFExtrinsicKit is available under Apache-2.0 OR MIT, at your option. See [LICENSE](LICENSE) for the license choices and original notices.
