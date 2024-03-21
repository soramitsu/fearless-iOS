import Foundation
import RobinHood
import SSFUtils
import IrohaCrypto
import SSFModels

typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
typealias ExtrinsicBuilderIndexedClosure = (ExtrinsicBuilderProtocol, Int) throws -> (ExtrinsicBuilderProtocol)

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

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<SubmitAndWatchExtrinsicResult>

    func createGenesisBlockHashOperation() -> BaseOperation<String>
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

final class ExtrinsicOperationFactory {
    let accountId: AccountId
    let cryptoType: CryptoType
    let chainFormat: ChainFormat
    let runtimeRegistry: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    let eraOperationFactory: ExtrinsicEraOperationFactoryProtocol

    @available(*, deprecated, message: "Use init(accountId:cryptoType:) instead")
    init(
        address: String,
        cryptoType _: CryptoType,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol = MortalEraOperationFactory()
    ) {
        accountId = (try? address.toAccountId()) ?? Data(repeating: 0, count: 32)
        chainFormat = .ethereum
        cryptoType = .ecdsa
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.eraOperationFactory = eraOperationFactory
    }

    init(
        accountId: AccountId,
        chainFormat: ChainFormat,
        cryptoType: CryptoType,
        runtimeRegistry: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        eraOperationFactory: ExtrinsicEraOperationFactoryProtocol = MortalEraOperationFactory()
    ) {
        self.accountId = accountId
        self.chainFormat = chainFormat
        self.cryptoType = cryptoType
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.eraOperationFactory = eraOperationFactory
    }

    private func createNonceOperation() -> BaseOperation<UInt32> {
        do {
            let address = try accountId.toAddress(using: chainFormat)
            return JSONRPCListOperation<UInt32>(
                engine: engine,
                method: RPCMethod.getExtrinsicNonce,
                parameters: [address]
            )
        } catch {
            return BaseOperation.createWithError(error)
        }
    }

    private func createBlockHashOperation(
        connection: JSONRPCEngine,
        for numberClosure: @escaping () throws -> BlockNumber
    ) -> BaseOperation<String> {
        let requestOperation = JSONRPCListOperation<String>(
            engine: connection,
            method: RPCMethod.getBlockHash
        )

        requestOperation.configurationBlock = {
            do {
                let blockNumber = try numberClosure()
                requestOperation.parameters = [blockNumber.toHex()]
            } catch {
                requestOperation.result = .failure(error)
            }
        }

        return requestOperation
    }

    // swiftlint:disable:next function_body_length
    private func createExtrinsicOperation(
        customClosure: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics: Int,
        signingClosure: @escaping (Data) throws -> Data
    ) -> CompoundOperationWrapper<[Data]> {
        let currentCryptoType = cryptoType
        let currentAccountId = accountId
        let currentChainFormat = chainFormat

        let nonceOperation = createNonceOperation()
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let genesisBlockOperation = createGenesisBlockHashOperation()

        let eraWrapper = eraOperationFactory.createOperation(
            from: engine,
            runtimeService: runtimeRegistry
        )

        let eraBlockOperation = createBlockHashOperation(
            connection: engine
        ) {
            try eraWrapper.targetOperation.extractNoCancellableResultData().blockNumber
        }

        eraBlockOperation.addDependency(eraWrapper.targetOperation)

        let extrinsicsOperation = ClosureOperation<[Data]> {
            let nonce = try nonceOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let genesisHash = try genesisBlockOperation.extractNoCancellableResultData()
            let era = try eraWrapper.targetOperation.extractNoCancellableResultData().extrinsicEra
            let eraBlockHash = try eraBlockOperation.extractNoCancellableResultData()

            let account: MultiAddress = codingFactory.metadata.multiAddressParameter(
                accountId: currentAccountId,
                chainFormat: currentChainFormat.asSfCrypto()
            )
            let extrinsics: [Data] = try (0 ..< numberOfExtrinsics).map { index in
                var builder: ExtrinsicBuilderProtocol =
                    try ExtrinsicBuilder(
                        specVersion: codingFactory.specVersion,
                        transactionVersion: codingFactory.txVersion,
                        genesisHash: genesisHash /* ,
                         runtimeMetadataProvider: runtimeRegistry */
                    )
                    .with(address: account)
                    .with(era: era, blockHash: eraBlockHash)
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

        let dependencies = [nonceOperation, codingFactoryOperation, genesisBlockOperation] +
            eraWrapper.allOperations + [eraBlockOperation]

        dependencies.forEach { extrinsicsOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: extrinsicsOperation,
            dependencies: dependencies
        )
    }
}

extension ExtrinsicOperationFactory: ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics: Int
    )
        -> CompoundOperationWrapper<[FeeExtrinsicResult]> {
        let currentCryptoType = cryptoType

        let signingClosure: (Data) throws -> Data = { data in
            try DummySigner(cryptoType: currentCryptoType).sign(data).rawData()
        }

        let builderWrapper = createExtrinsicOperation(
            customClosure: closure,
            numberOfExtrinsics: numberOfExtrinsics,
            signingClosure: signingClosure
        )

        let feeOperationList: [JSONRPCListOperation<RuntimeDispatchInfo>] =
            (0 ..< numberOfExtrinsics).map { index in
                let infoOperation = JSONRPCListOperation<RuntimeDispatchInfo>(
                    engine: engine,
                    method: RPCMethod.paymentInfo
                )

                infoOperation.configurationBlock = {
                    do {
                        let extrinsics = try builderWrapper.targetOperation.extractNoCancellableResultData()
                        let extrinsic = extrinsics[index].toHex(includePrefix: true)
                        infoOperation.parameters = [extrinsic]
                    } catch {
                        infoOperation.result = .failure(error)
                    }
                }

                infoOperation.addDependency(builderWrapper.targetOperation)

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
            dependencies: builderWrapper.allOperations + feeOperationList
        )
    }

    func submitAndWatch(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<SubmitAndWatchExtrinsicResult> {
        let wrapperClosure: ExtrinsicBuilderIndexedClosure = { builder, _ in
            try closure(builder)
        }

        let signingClosure: (Data) throws -> Data = { data in
            try signer.sign(data).rawData()
        }

        let builderWrapper = createExtrinsicOperation(
            customClosure: wrapperClosure,
            numberOfExtrinsics: 1,
            signingClosure: signingClosure
        )

        let submitOperation = JSONRPCListOperation<String>(
            engine: engine,
            method: "author_submitAndWatchExtrinsic", // TODO: add to fearless utils
            parameters: nil,
            timeout: 60
        )
        submitOperation.configurationBlock = {
            do {
                guard let extrinsic = try builderWrapper
                    .targetOperation
                    .extractNoCancellableResultData()
                    .first?
                    .toHex(includePrefix: true)
                else {
                    throw BaseOperationError.unexpectedDependentResult
                }

                submitOperation.parameters = [extrinsic]
            } catch {
                submitOperation.result = .failure(error)
            }
        }

        submitOperation.addDependency(builderWrapper.targetOperation)

        let wrapperOperation = ClosureOperation<SubmitAndWatchExtrinsicResult> {
            if let result = submitOperation.result {
                return (result, submitOperation.parameters?.first)
            } else {
                throw BaseOperationError.unexpectedDependentResult
            }
        }

        wrapperOperation.addDependency(submitOperation)

        return CompoundOperationWrapper(
            targetOperation: wrapperOperation,
            dependencies: builderWrapper.allOperations + [submitOperation]
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderIndexedClosure,
        signer: SigningWrapperProtocol,
        numberOfExtrinsics: Int
    ) -> CompoundOperationWrapper<[SubmitExtrinsicResult]> {
        let signingClosure: (Data) throws -> Data = { data in
            try signer.sign(data).rawData()
        }

        let builderWrapper = createExtrinsicOperation(
            customClosure: closure,
            numberOfExtrinsics: numberOfExtrinsics,
            signingClosure: signingClosure
        )

        let submitOperationList: [JSONRPCListOperation<String>] =
            (0 ..< numberOfExtrinsics).map { index in
                let submitOperation = JSONRPCListOperation<String>(
                    engine: engine,
                    method: RPCMethod.submitExtrinsic
                )

                submitOperation.configurationBlock = {
                    do {
                        let extrinsics = try builderWrapper.targetOperation.extractNoCancellableResultData()
                        let extrinsic = extrinsics[index].toHex(includePrefix: true)

                        submitOperation.parameters = [extrinsic]
                    } catch {
                        submitOperation.result = .failure(error)
                    }
                }

                submitOperation.addDependency(builderWrapper.targetOperation)

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
            dependencies: builderWrapper.allOperations + submitOperationList
        )
    }

    func createGenesisBlockHashOperation() -> BaseOperation<String> {
        createBlockHashOperation(
            connection: engine,
            for: { 0 }
        )
    }
}
