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
    let cryptoType: CryptoType
    let logger: LoggerProtocol

    init(url: URL,
         accountSettings: WalletAccountSettingsProtocol,
         cryptoType: CryptoType,
         accountSigner: IRSignatureCreatorProtocol,
         dummySigner: IRSignatureCreatorProtocol,
         logger: LoggerProtocol) {
        self.url = url
        self.accountSettings = accountSettings
        self.cryptoType = cryptoType
        self.accountSigner = accountSigner
        self.dummySigner = dummySigner
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
            return createBaseOperation(result: .failure(error))
        }
    }

    func createStakingLedgerFetchOperation(_ accountId: Data? = nil,
                                           engine: JSONRPCEngine? = nil)
        -> CompoundOperationWrapper<JSONScaleDecodable<StakingLedger>> {
        do {
            let currentEngine = engine ?? WebSocketEngine(url: url, logger: logger)

            let storageKeyFactory = StorageKeyFactory()
            let stashId = try (accountId ?? Data(hexString: accountSettings.accountId))

            let serviceKey = try storageKeyFactory.createStorageKey(moduleName: "Staking",
                                                                    serviceName: "Bonded")

            let stashKey = (serviceKey + stashId.twox64Concat()).toHex(includePrefix: true)

            let controllerOperation =
                JSONRPCOperation<JSONScaleDecodable<AccountId>>(engine: currentEngine,
                                                                method: RPCMethod.getStorage,
                                                                parameters: [stashKey])

            let infoOperation =
                JSONRPCOperation<JSONScaleDecodable<StakingLedger>>(engine: currentEngine,
                                                                    method: RPCMethod.getStorage)

            infoOperation.configurationBlock = {
                do {
                    let accountIdWrapper = try controllerOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                    if let controllerId = accountIdWrapper.underlyingValue?.value {
                        let infoKey = try storageKeyFactory.createStorageKey(moduleName: "Staking",
                                                                               serviceName: "Ledger",
                                                                               identifier: controllerId)
                            .toHex(includePrefix: true)

                        infoOperation.parameters = [infoKey]
                    } else {
                        let info = JSONScaleDecodable<StakingLedger>(value: nil)
                        infoOperation.result = .success(info)
                    }
                } catch {
                    infoOperation.result = .failure(error)
                }
            }

            infoOperation.addDependency(controllerOperation)

            return CompoundOperationWrapper(targetOperation: infoOperation,
                                            dependencies: [controllerOperation])

        } catch {
            return createCompoundOperation(result: .failure(error))
        }
    }

    func createStorageFetchOperation<T: Decodable>(moduleName: String,
                                                   serviceName: String,
                                                   identifier: Data? = nil,
                                                   engine: JSONRPCEngine? = nil) -> BaseOperation<T> {
        do {
            let currentEngine = engine ?? WebSocketEngine(url: url, logger: logger)

            let key: String
            let storageKeyFactory = StorageKeyFactory()

            if let identifier = identifier {
                key = try storageKeyFactory.createStorageKey(moduleName: moduleName,
                                                             serviceName: serviceName,
                                                             identifier: identifier)
                    .toHex(includePrefix: true)
            } else {
                key = try storageKeyFactory.createStorageKey(moduleName: moduleName,
                                                             serviceName: serviceName)
                    .toHex(includePrefix: true)
            }

            return JSONRPCOperation<T>(engine: currentEngine,
                                       method: RPCMethod.getStorage,
                                       parameters: [key])
        } catch {
            return createBaseOperation(result: .failure(error))
        }
    }

    func createActiveEraFetchOperation(engine: JSONRPCEngine? = nil)
        -> BaseOperation<JSONScaleDecodable<UInt32>> {
        return createStorageFetchOperation(moduleName: "Staking",
                                           serviceName: "ActiveEra",
                                           engine: engine)
    }

    func createRuntimeVersionOperation(engine: JSONRPCEngine? = nil) -> BaseOperation<RuntimeVersion> {
        let currentEngine = engine ?? WebSocketEngine(url: url, logger: logger)
        return JSONRPCOperation(engine: currentEngine, method: RPCMethod.getRuntimeVersion)
    }

    func setupTransferExtrinsic<T>(_ targetOperation: JSONRPCOperation<T>,
                                   amount: BigUInt,
                                   receiver: String,
                                   chain: Chain,
                                   signer: IRSignatureCreatorProtocol) -> CompoundOperationWrapper<T> {
        let accountInfoOperation = createAccountInfoFetchOperation(engine: targetOperation.engine)
        let runtimeVersionOperation = createRuntimeVersionOperation(engine: targetOperation.engine)

        let sender = accountSettings.accountId
        let currentCryptoType = cryptoType

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
                let genesisHashData = try Data(hexString: chain.genesisHash)

                let additionalParameters = ExtrinsicParameters(nonce: nonce,
                                                               genesisHash: genesisHashData,
                                                               specVersion: runtimeVersion.specVersion,
                                                               transactionVersion: runtimeVersion.transactionVersion,
                                                               signatureVersion: currentCryptoType.version)

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
        let baseOperation = createBaseOperation(result: result)
        return CompoundOperationWrapper(targetOperation: baseOperation)
    }

    func createBaseOperation<T>(result: Result<T, Error>) -> BaseOperation<T> {
        let baseOperation: BaseOperation<T> = BaseOperation()
        baseOperation.result = result
        return baseOperation
    }
}
