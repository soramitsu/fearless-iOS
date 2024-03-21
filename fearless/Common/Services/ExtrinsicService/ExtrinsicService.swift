import Foundation
import SSFUtils
import RobinHood
import IrohaCrypto
import SSFModels

typealias FeeExtrinsicResult = Result<RuntimeDispatchInfo, Error>
typealias EstimateFeeClosure = (FeeExtrinsicResult) -> Void
typealias EstimateFeeIndexedClosure = ([FeeExtrinsicResult]) -> Void

typealias SubmitAndWatchExtrinsicResult = (result: Result<String, Error>, extrinsicHash: String?)
typealias SubmitExtrinsicResult = Result<String, Error>
typealias ExtrinsicSubmitClosure = (SubmitExtrinsicResult) -> Void
typealias ExtrinsicSubmitIndexedClosure = ([SubmitExtrinsicResult]) -> Void
typealias ExtrinsicSubmitAndWatchClosure = (Result<String, Error>, _ extrinsicHash: String?) -> Void

protocol ExtrinsicServiceProtocol {
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
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    )

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    )

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitAndWatchClosure
    )
}

final class ExtrinsicService {
    let operationFactory: ExtrinsicOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    @available(*, deprecated, message: "Use init(accountId:cryptoType:) instead")
    init(
        address: String,
        cryptoType: CryptoType,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol
    ) {
        operationFactory = ExtrinsicOperationFactory(
            address: address,
            cryptoType: cryptoType,
            runtimeRegistry: runtimeRegistry,
            engine: engine
        )

        self.operationManager = operationManager
    }

    init(
        accountId: AccountId,
        chainFormat: ChainFormat,
        cryptoType: CryptoType,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        operationManager: OperationManagerProtocol
    ) {
        operationFactory = ExtrinsicOperationFactory(
            accountId: accountId,
            chainFormat: chainFormat,
            cryptoType: cryptoType,
            runtimeRegistry: runtimeRegistry,
            engine: engine
        )

        self.operationManager = operationManager
    }
}

extension ExtrinsicService: ExtrinsicServiceProtocol {
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        let wrapper = operationFactory.estimateFeeOperation(closure)

        wrapper.targetOperation.completionBlock = {
            queue.async {
                if let result = wrapper.targetOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        let wrapper = operationFactory.estimateFeeOperation(
            closure,
            numberOfExtrinsics: numberOfExtrinsics
        )

        wrapper.targetOperation.completionBlock = {
            queue.async {
                do {
                    let result = try wrapper.targetOperation.extractNoCancellableResultData()
                    completionClosure(result)
                } catch {
                    let result: [FeeExtrinsicResult] = Array(
                        repeating: .failure(error),
                        count: numberOfExtrinsics
                    )
                    completionClosure(result)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitAndWatchClosure
    ) {
        let wrapper: CompoundOperationWrapper<SubmitAndWatchExtrinsicResult> = operationFactory
            .submitAndWatch(closure, signer: signer)

        wrapper.targetOperation.completionBlock = {
            queue.async {
                if let result = wrapper.targetOperation.result {
                    switch result {
                    case let .success(submitAndWatchExtrinsicResult):
                        completionClosure(submitAndWatchExtrinsicResult.result, submitAndWatchExtrinsicResult.extrinsicHash)
                    case .failure:
                        completionClosure(.failure(BaseOperationError.parentOperationCancelled), nil)
                    }
                } else {
                    completionClosure(.failure(BaseOperationError.unexpectedDependentResult), nil)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        let wrapper = operationFactory.submit(closure, signer: signer)

        wrapper.targetOperation.completionBlock = {
            queue.async {
                if let result = wrapper.targetOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        numberOfExtrinsics: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        let wrapper = operationFactory.submit(closure, signer: signer, numberOfExtrinsics: numberOfExtrinsics)

        wrapper.targetOperation.completionBlock = {
            queue.async {
                do {
                    let operationResult = try wrapper.targetOperation.extractNoCancellableResultData()
                    completionClosure(operationResult)
                } catch {
                    let results: [SubmitExtrinsicResult] = Array(
                        repeating: .failure(error),
                        count: numberOfExtrinsics
                    )
                    completionClosure(results)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }
}
