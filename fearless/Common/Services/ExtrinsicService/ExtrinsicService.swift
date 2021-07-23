import Foundation
import FearlessUtils
import RobinHood
import IrohaCrypto

typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
typealias ExtrinsicBuilderIndexedClosure = (ExtrinsicBuilderProtocol, Int) throws -> (ExtrinsicBuilderProtocol)

typealias FeeExtrinsicResult = Result<RuntimeDispatchInfo, Error>
typealias EstimateFeeClosure = (FeeExtrinsicResult) -> Void
typealias EstimateFeeIndexedClosure = ([FeeExtrinsicResult]) -> Void

typealias SubmitExtrinsicResult = Result<String, Error>
typealias ExtrinsicSubmitClosure = (SubmitExtrinsicResult) -> Void
typealias ExtrinsicSubmitIndexedClosure = ([SubmitExtrinsicResult]) -> Void

protocol ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics: Int
    )
        -> CompoundOperationWrapper<[FeeExtrinsicResult]>

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<[SubmitExtrinsicResult]>
}

extension ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(_ closure: @escaping ExtrinsicBuilderClosure)
        -> CompoundOperationWrapper<RuntimeDispatchInfo> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }

        let feeOperation = estimateFeeOperation(
            wrapperClosure,
            numberOfExtrinsics: 1
        )

        let resultMappingOperation = ClosureOperation<RuntimeDispatchInfo> {
            guard let result = try feeOperation.targetOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return try result.get()
        }

        resultMappingOperation.addDependency(feeOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultMappingOperation,
            dependencies: feeOperation.allOperations
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<String> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }

        let submitOperation = submit(
            wrapperClosure,
            signer: signer,
            numberOfExtrinsics: 1
        )

        let resultMappingOperation = ClosureOperation<String> {
            guard let result = try submitOperation.targetOperation.extractNoCancellableResultData().first else {
                throw BaseOperationError.unexpectedDependentResult
            }

            return try result.get()
        }

        resultMappingOperation.addDependency(submitOperation.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: resultMappingOperation,
            dependencies: submitOperation.allOperations
        )
    }
}

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
}

final class ExtrinsicOperationFactory {
    let address: String
    let cryptoType: CryptoType
    let runtimeRegistry: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine

    init(
        address: String,
        cryptoType: CryptoType,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine
    ) {
        self.address = address
        self.cryptoType = cryptoType
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
    }

    private func createNonceOperation() -> BaseOperation<UInt32> {
        JSONRPCListOperation<UInt32>(
            engine: engine,
            method: RPCMethod.getExtrinsicNonce,
            parameters: [address]
        )
    }

    private func createCodingFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        runtimeRegistry.fetchCoderFactoryOperation()
    }

    private func createExtrinsicOperation(
        dependingOn nonceOperation: BaseOperation<UInt32>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        customClosure: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics: Int,
        signingClosure: @escaping (Data) throws -> Data
    ) -> BaseOperation<[Data]> {
        let currentCryptoType = cryptoType
        let currentAddress = address

        return ClosureOperation {
            let nonce = try nonceOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let addressFactory = SS58AddressFactory()

            let addressType = try addressFactory.extractAddressType(from: currentAddress)
            let accountId = try addressFactory.accountId(fromAddress: currentAddress, type: addressType)

            let account = MultiAddress.accoundId(accountId)

            let extrinsics: [Data] = try (0 ..< numberOfExtrinsics).map { index in
                var builder: ExtrinsicBuilderProtocol =
                    try ExtrinsicBuilder(
                        specVersion: codingFactory.specVersion,
                        transactionVersion: codingFactory.txVersion,
                        genesisHash: addressType.chain.genesisHash
                    )
                    .with(address: account)
                    .with(nonce: nonce + UInt32(index))

                builder = try customClosure(builder, index).signing(
                    by: signingClosure,
                    of: currentCryptoType.utilsType,
                    using: codingFactory.createEncoder(),
                    metadata: codingFactory.metadata
                )

                return try builder.build(
                    encodingBy: codingFactory.createEncoder(),
                    metadata: codingFactory.metadata
                )
            }

            return extrinsics
        }
    }
}

extension ExtrinsicOperationFactory: ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics: Int
    )
        -> CompoundOperationWrapper<[FeeExtrinsicResult]> {
        let nonceOperation = createNonceOperation()
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let currentCryptoType = cryptoType

        let signingClosure: (Data) throws -> Data = { data in
            try DummySigner(cryptoType: currentCryptoType).sign(data).rawData()
        }

        let builderOperation = createExtrinsicOperation(
            dependingOn: nonceOperation,
            codingFactoryOperation: codingFactoryOperation,
            customClosure: closure,
            numberOfExtrinsics: numberOfExtrinsics,
            signingClosure: signingClosure
        )

        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(codingFactoryOperation)

        let feeOperationList: [JSONRPCListOperation<RuntimeDispatchInfo>] =
            (0 ..< numberOfExtrinsics).map { index in
                let infoOperation = JSONRPCListOperation<RuntimeDispatchInfo>(
                    engine: engine,
                    method: RPCMethod.paymentInfo
                )

                infoOperation.configurationBlock = {
                    do {
                        let extrinsic = try builderOperation.extractNoCancellableResultData()[index]
                            .toHex(includePrefix: true)
                        infoOperation.parameters = [extrinsic]
                    } catch {
                        infoOperation.result = .failure(error)
                    }
                }

                infoOperation.addDependency(builderOperation)

                return infoOperation
            }

        let wrapperOperation = ClosureOperation<[FeeExtrinsicResult]> {
            feeOperationList.map { feeOperation in
                if let result = feeOperation.result {
                    return result
                } else {
                    return .failure(BaseOperationError.parentOperationCancelled)
                }
            }
        }

        feeOperationList.forEach { feeOperation in
            wrapperOperation.addDependency(feeOperation)
        }

        return CompoundOperationWrapper(
            targetOperation: wrapperOperation,
            dependencies: [nonceOperation, codingFactoryOperation, builderOperation] + feeOperationList
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<[SubmitExtrinsicResult]> {
        let nonceOperation = createNonceOperation()
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let signingClosure: (Data) throws -> Data = { data in
            try signer.sign(data).rawData()
        }

        let builderOperation = createExtrinsicOperation(
            dependingOn: nonceOperation,
            codingFactoryOperation: codingFactoryOperation,
            customClosure: closure,
            numberOfExtrinsics: numberOfExtrinsics,
            signingClosure: signingClosure
        )

        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(codingFactoryOperation)

        let submitOperationList: [JSONRPCListOperation<String>] =
            (0 ..< numberOfExtrinsics).map { index in
                let submitOperation = JSONRPCListOperation<String>(
                    engine: engine,
                    method: RPCMethod.submitExtrinsic
                )

                submitOperation.configurationBlock = {
                    do {
                        let extrinsic = try builderOperation
                            .extractNoCancellableResultData()[index]
                            .toHex(includePrefix: true)

                        submitOperation.parameters = [extrinsic]
                    } catch {
                        submitOperation.result = .failure(error)
                    }
                }

                submitOperation.addDependency(builderOperation)

                return submitOperation
            }

        let wrapperOperation = ClosureOperation<[SubmitExtrinsicResult]> {
            submitOperationList.map { submitOperation in
                if let result = submitOperation.result {
                    return result
                } else {
                    return .failure(BaseOperationError.parentOperationCancelled)
                }
            }
        }

        submitOperationList.forEach { submitOperation in
            wrapperOperation.addDependency(submitOperation)
        }

        return CompoundOperationWrapper(
            targetOperation: wrapperOperation,
            dependencies: [nonceOperation, codingFactoryOperation, builderOperation] + submitOperationList
        )
    }
}

final class ExtrinsicService {
    let operationFactory: ExtrinsicOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

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
