import Foundation
import FearlessUtils
import RobinHood
import IrohaCrypto

typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
typealias EstimateFeeClosure = (Result<RuntimeDispatchInfo, Error>) -> Void
typealias ExtrinsicSubmitClosure = (Result<String, Error>) -> Void

protocol ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(_ closure: @escaping ExtrinsicBuilderClosure)
        -> CompoundOperationWrapper<RuntimeDispatchInfo>

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<String>
}

protocol ExtrinsicServiceProtocol {
    func estimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    )

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
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
        customClosure: @escaping ExtrinsicBuilderClosure,
        signingClosure: @escaping (Data) throws -> Data
    ) -> BaseOperation<Data> {
        let currentCryptoType = cryptoType
        let currentAddress = address

        return ClosureOperation {
            let nonce = try nonceOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let addressFactory = SS58AddressFactory()

            let addressType = try addressFactory.extractAddressType(from: currentAddress)
            let accountId = try addressFactory.accountId(fromAddress: currentAddress, type: addressType)

            let account = MultiAddress.accoundId(accountId)

            var builder: ExtrinsicBuilderProtocol =
                try ExtrinsicBuilder(
                    specVersion: codingFactory.specVersion,
                    transactionVersion: codingFactory.txVersion,
                    genesisHash: addressType.chain.genesisHash
                )
                .with(address: account)
                .with(nonce: nonce)

            builder = try customClosure(builder).signing(
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
    }
}

extension ExtrinsicOperationFactory: ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(_ closure: @escaping ExtrinsicBuilderClosure)
        -> CompoundOperationWrapper<RuntimeDispatchInfo> {
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
            signingClosure: signingClosure
        )

        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(codingFactoryOperation)

        let infoOperation = JSONRPCListOperation<RuntimeDispatchInfo>(
            engine: engine,
            method: RPCMethod.paymentInfo
        )

        infoOperation.configurationBlock = {
            do {
                let extrinsic = try builderOperation.extractNoCancellableResultData().toHex(includePrefix: true)
                infoOperation.parameters = [extrinsic]
            } catch {
                infoOperation.result = .failure(error)
            }
        }

        infoOperation.addDependency(builderOperation)

        return CompoundOperationWrapper(
            targetOperation: infoOperation,
            dependencies: [nonceOperation, codingFactoryOperation, builderOperation]
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<String> {
        let nonceOperation = createNonceOperation()
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let signingClosure: (Data) throws -> Data = { data in
            try signer.sign(data).rawData()
        }

        let builderOperation = createExtrinsicOperation(
            dependingOn: nonceOperation,
            codingFactoryOperation: codingFactoryOperation,
            customClosure: closure,
            signingClosure: signingClosure
        )

        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(codingFactoryOperation)

        let submitOperation = JSONRPCListOperation<String>(
            engine: engine,
            method: RPCMethod.submitExtrinsic
        )
        submitOperation.configurationBlock = {
            do {
                let extrinsic = try builderOperation
                    .extractNoCancellableResultData()
                    .toHex(includePrefix: true)

                submitOperation.parameters = [extrinsic]
            } catch {
                submitOperation.result = .failure(error)
            }
        }

        submitOperation.addDependency(builderOperation)

        return CompoundOperationWrapper(
            targetOperation: submitOperation,
            dependencies: [nonceOperation, codingFactoryOperation, builderOperation]
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
}
