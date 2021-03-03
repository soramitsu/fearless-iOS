import Foundation
import FearlessUtils
import RobinHood
import IrohaCrypto

typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
typealias EstimateFeeClosure = (Result<RuntimeDispatchInfo, Error>) -> Void
typealias ExtrinsicSubmitClosure = (Result<String, Error>) -> Void

protocol ExtrinsicServiceProtocol {
    func estimateFee(_ closure: @escaping ExtrinsicBuilderClosure,
                     runningIn queue: DispatchQueue,
                     completion completionClosure: @escaping EstimateFeeClosure)

    func submit(_ closure: @escaping ExtrinsicBuilderClosure,
                signer: SigningWrapperProtocol,
                runningIn queue: DispatchQueue,
                completion completionClosure: @escaping ExtrinsicSubmitClosure)
}

final class ExtrinsicService {
    let address: String
    let cryptoType: CryptoType
    let runtimeRegistry: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol

    init(address: String,
         cryptoType: CryptoType,
         runtimeRegistry: RuntimeCodingServiceProtocol,
         engine: JSONRPCEngine,
         operationManager: OperationManagerProtocol) {
        self.address = address
        self.cryptoType = cryptoType
        self.runtimeRegistry = runtimeRegistry
        self.engine = engine
        self.operationManager = operationManager
    }

    private func createNonceOperation() -> BaseOperation<UInt32> {
        JSONRPCListOperation<UInt32>(engine: engine,
                                     method: RPCMethod.getExtrinsicNonce,
                                     parameters: [address])
    }

    private func createCodingFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        runtimeRegistry.fetchCoderFactoryOperation()
    }

    private func createExtrinsicOperation(dependingOn nonceOperation: BaseOperation<UInt32>,
                                          codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
                                          customClosure: @escaping ExtrinsicBuilderClosure,
                                          signingClosure: @escaping (Data) throws -> Data)
    -> BaseOperation<Data> {

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
                try ExtrinsicBuilder(specVersion: codingFactory.specVersion,
                                     transactionVersion: codingFactory.txVersion,
                                     genesisHash: addressType.chain.genesisHash)
                    .with(address: account)
                    .with(nonce: nonce)

            builder = try customClosure(builder).signing(by: signingClosure,
                                                         of: currentCryptoType.utilsType,
                                                         using: codingFactory.createEncoder(),
                                                         metadata: codingFactory.metadata)

            return try builder.build(encodingBy: codingFactory.createEncoder(),
                                     metadata: codingFactory.metadata)
        }
    }
}

extension ExtrinsicService: ExtrinsicServiceProtocol {
    func estimateFee(_ closure: @escaping ExtrinsicBuilderClosure,
                     runningIn queue: DispatchQueue,
                     completion completionClosure: @escaping EstimateFeeClosure) {
        let nonceOperation = createNonceOperation()
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let currentCryptoType = cryptoType

        let signingClosure: (Data) throws -> Data = { data in
            let sigData = data.count < ExtrinsicConstants.maxNonHashLength ? data : try data.blake2b32()
            return try DummySigner(cryptoType: currentCryptoType).sign(sigData).rawData()
        }

        let builderOperation = createExtrinsicOperation(dependingOn: nonceOperation,
                                                        codingFactoryOperation: codingFactoryOperation,
                                                        customClosure: closure,
                                                        signingClosure: signingClosure)

        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(codingFactoryOperation)

        let infoOperation = JSONRPCListOperation<RuntimeDispatchInfo>(engine: engine,
                                                                      method: RPCMethod.paymentInfo)
        infoOperation.configurationBlock = {
            do {
                let extrinsic = try builderOperation.extractNoCancellableResultData().toHex(includePrefix: true)
                infoOperation.parameters = [extrinsic]
            } catch {
                infoOperation.result = .failure(error)
            }
        }

        infoOperation.addDependency(builderOperation)

        infoOperation.completionBlock = {
            queue.async {
                if let result = infoOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        let operations = [nonceOperation, codingFactoryOperation, builderOperation, infoOperation]
        operationManager.enqueue(operations: operations, in: .transient)
    }

    func submit(_ closure: @escaping ExtrinsicBuilderClosure,
                signer: SigningWrapperProtocol,
                runningIn queue: DispatchQueue,
                completion completionClosure: @escaping ExtrinsicSubmitClosure) {
        let nonceOperation = createNonceOperation()
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()

        let signingClosure: (Data) throws -> Data = { data in
            let sigData = data.count < ExtrinsicConstants.maxNonHashLength ? data : try data.blake2b32()
            return try signer.sign(sigData).rawData()
        }

        let builderOperation = createExtrinsicOperation(dependingOn: nonceOperation,
                                                        codingFactoryOperation: codingFactoryOperation,
                                                        customClosure: closure,
                                                        signingClosure: signingClosure)

        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(codingFactoryOperation)

        let submitOperation = JSONRPCListOperation<String>(engine: engine,
                                                           method: RPCMethod.submitExtrinsic)
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

        submitOperation.completionBlock = {
            queue.async {
                if let result = submitOperation.result {
                    completionClosure(result)
                } else {
                    completionClosure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        let operations = [nonceOperation, codingFactoryOperation, builderOperation, submitOperation]
        operationManager.enqueue(operations: operations, in: .transient)
    }
}
