import Foundation
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt
import FearlessUtils

final class WalletNetworkOperationFactory {
    let accountSettings: WalletAccountSettingsProtocol
    let url: URL
    let accountSigner: IRSignatureCreatorProtocol
    let dummySigner: IRSignatureCreatorProtocol
    let genesisHash: Data
    let logger: LoggerProtocol

    init(url: URL,
         accountSettings: WalletAccountSettingsProtocol,
         accountSigner: IRSignatureCreatorProtocol,
         dummySigner: IRSignatureCreatorProtocol,
         genesisHash: Data,
         logger: LoggerProtocol) {
        self.url = url
        self.accountSettings = accountSettings
        self.accountSigner = accountSigner
        self.dummySigner = dummySigner
        self.genesisHash = genesisHash
        self.logger = logger
    }

    func createGenisisHashOperation(engine: JSONRPCEngine? = nil) -> BaseOperation<String> {
        createBlockHashOperation(0)
    }

    func createBlockHashOperation(_ block: UInt32, engine: JSONRPCEngine? = nil) -> BaseOperation<String> {
        let currentEngine = engine ?? WebSocketEngine(url: url, logger: logger)

        var currentBlock = block
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCOperation<String>(engine: currentEngine,
                                        method: RPCMethod.getBlockHash,
                                        parameters: [param])
    }

    func createAccountInfoFetchOperation(_ accountId: Data? = nil, engine: JSONRPCEngine? = nil)
        -> BaseOperation<JSONScaleDecodable<AccountInfo>> {
        do {
            let identifier = try (accountId ?? Data(hexString: accountSettings.accountId))

            return createStorageFetchOperation(moduleName: "System",
                                               serviceName: "Account",
                                               identifier: identifier,
                                               engine: engine)
        } catch {
            let operation = BaseOperation<JSONScaleDecodable<AccountInfo>>()
            operation.result = .failure(error)
            return operation
        }

    }

    func createStorageFetchOperation<T: Decodable>(moduleName: String,
                                                   serviceName: String,
                                                   identifier: Data,
                                                   engine: JSONRPCEngine? = nil) -> BaseOperation<T> {
        do {
            let currentEngine = engine ?? WebSocketEngine(url: url, logger: logger)

            let key = try StorageKeyFactory().createStorageKey(moduleName: moduleName,
                                                               serviceName: serviceName,
                                                               identifier: identifier).toHex(includePrefix: true)

            return JSONRPCOperation<T>(engine: currentEngine,
                                       method: RPCMethod.getStorage,
                                       parameters: [key])
        } catch {
            let operation = BaseOperation<T>()
            operation.result = .failure(error)
            return operation
        }
    }

    func createRuntimeVersionOperation(engine: JSONRPCEngine? = nil) -> BaseOperation<RuntimeVersion> {
        let currentEngine = engine ?? WebSocketEngine(url: url, logger: logger)
        return JSONRPCOperation(engine: currentEngine, method: RPCMethod.getRuntimeVersion)
    }

    func setupTransferExtrinsic<T>(_ targetOperation: JSONRPCOperation<T>,
                                   amount: BigUInt,
                                   sender: String,
                                   receiver: String,
                                   signer: IRSignatureCreatorProtocol) -> CompoundOperationWrapper<T> {
        let accountInfoOperation = createAccountInfoFetchOperation(engine: targetOperation.engine)
        let runtimeVersionOperation = createRuntimeVersionOperation(engine: targetOperation.engine)

        let currentGenesisHash = genesisHash

        targetOperation.configurationBlock = {
            do {
                let nonce = try accountInfoOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    .underlyingValue?
                    .nonce ?? 0

                let runtimeVersion = try runtimeVersionOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                let receiverAccountId = try Data(hexString: receiver)
                let senderAccountId = try Data(hexString: sender)

                let additionalParameters = ExtrinsicParameters(nonce: nonce,
                                                               genesisHash: currentGenesisHash,
                                                               specVersion: runtimeVersion.specVersion,
                                                               transactionVersion: runtimeVersion.transactionVersion)

                let extrinsicData = try ExtrinsicFactory.transferExtrinsic(from: senderAccountId,
                                                                           to: receiverAccountId,
                                                                           amount: amount,
                                                                           additionalParameters: additionalParameters,
                                                                           signer: signer)

                targetOperation.parameters = [extrinsicData.toHex(includePrefix: true)]
            } catch {
                targetOperation.result = .failure(error)
            }
        }

        let dependencies: [Operation] = [accountInfoOperation, runtimeVersionOperation]

        dependencies.forEach { targetOperation.addDependency($0)}

        return CompoundOperationWrapper(targetOperation: targetOperation,
                                        dependencies: dependencies)
    }

    func createCompoundOperation<T>(result: Result<T, Error>) -> CompoundOperationWrapper<T> {
        let baseOperation: BaseOperation<T> = BaseOperation()
        baseOperation.result = result
        return CompoundOperationWrapper(targetOperation: baseOperation)
    }
}
