import Foundation
import CommonWallet
import RobinHood
import IrohaCrypto
import BigInt
import FearlessUtils

final class WalletNetworkOperationFactory {
    let accountSettings: WalletAccountSettingsProtocol
    let engine: JSONRPCEngine
    let accountSigner: IRSignatureCreatorProtocol
    let dummySigner: IRSignatureCreatorProtocol
    let cryptoType: CryptoType
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let localStorageIdFactory: ChainStorageIdFactoryProtocol

    init(
        engine: JSONRPCEngine,
        accountSettings: WalletAccountSettingsProtocol,
        cryptoType: CryptoType,
        accountSigner: IRSignatureCreatorProtocol,
        dummySigner: IRSignatureCreatorProtocol,
        chainStorage: AnyDataProviderRepository<ChainStorageItem>,
        localStorageIdFactory: ChainStorageIdFactoryProtocol
    ) {
        self.engine = engine
        self.accountSettings = accountSettings
        self.cryptoType = cryptoType
        self.accountSigner = accountSigner
        self.dummySigner = dummySigner
        self.chainStorage = chainStorage
        self.localStorageIdFactory = localStorageIdFactory
    }

    func createGenisisHashOperation() -> BaseOperation<String> {
        createBlockHashOperation(0)
    }

    func createBlockHashOperation(_ block: UInt32) -> BaseOperation<String> {
        var currentBlock = block
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(
            engine: engine,
            method: RPCMethod.getBlockHash,
            parameters: [param]
        )
    }

    func createUpgradedInfoFetchOperation() -> CompoundOperationWrapper<Bool?> {
        do {
            let remoteKey = try StorageKeyFactory().updatedDualRefCount()
            let localKey = localStorageIdFactory.createIdentifier(for: remoteKey)

            return chainStorage.queryStorageByKey(localKey)

        } catch {
            return createCompoundOperation(result: .failure(error))
        }
    }

    func createAccountInfoFetchOperation(_ accountId: Data)
        -> CompoundOperationWrapper<AccountInfo?>
    {
        do {
            let storageKeyFactory = StorageKeyFactory()
            let accountIdKey = try storageKeyFactory.accountInfoKeyForId(accountId).toHex(includePrefix: true)

            let upgradedOperation = createUpgradedInfoFetchOperation()

            let operation = JSONRPCOperation<[[String]], [StorageUpdate]>(
                engine: engine,
                method: RPCMethod.queryStorageAt,
                parameters: [[accountIdKey]]
            )

            let mapOperation = ClosureOperation<AccountInfo?> {
                let storageUpdates = try operation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                let storageUpdateDataList = storageUpdates.map { update in
                    StorageUpdateData(update: update)
                }

                let upgraded = (try upgradedOperation.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)) ?? false

                let accountInfo: AccountInfo? = try storageUpdateDataList.reduce(nil) { result, updateData in
                    guard result == nil else {
                        return result
                    }

                    if upgraded {
                        if let value: AccountInfo = try updateData.decodeUpdatedData(for: accountIdKey) {
                            return value
                        } else {
                            return result
                        }
                    } else {
                        if let value: AccountInfoV27 = try updateData.decodeUpdatedData(for: accountIdKey) {
                            return AccountInfo(v27: value)
                        } else {
                            return result
                        }
                    }
                }

                return accountInfo
            }

            let dependencies = [operation] + upgradedOperation.allOperations

            dependencies.forEach { mapOperation.addDependency($0) }

            return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
        } catch {
            return createCompoundOperation(result: .failure(error))
        }
    }

    func createExtrinsicNonceFetchOperation(_ chain: Chain, accountId: Data? = nil) -> BaseOperation<UInt32> {
        do {
            let identifier = try (accountId ?? Data(hexString: accountSettings.accountId))

            let address = try SS58AddressFactory()
                .address(
                    fromPublicKey: AccountIdWrapper(rawData: identifier),
                    type: SNAddressType(chain: chain)
                )

            return JSONRPCListOperation<UInt32>(
                engine: engine,
                method: RPCMethod.getExtrinsicNonce,
                parameters: [address]
            )
        } catch {
            return createBaseOperation(result: .failure(error))
        }
    }

    func createRuntimeVersionOperation() -> BaseOperation<RuntimeVersion> {
        JSONRPCListOperation(engine: engine, method: RPCMethod.getRuntimeVersion)
    }

    func setupTransferExtrinsic<T>(
        _ targetOperation: JSONRPCListOperation<T>,
        amount: BigUInt,
        receiver: String,
        chain: Chain,
        signer: IRSignatureCreatorProtocol
    ) -> CompoundOperationWrapper<T> {
        let sender = accountSettings.accountId
        let currentCryptoType = cryptoType

        let upgradedOperation = createUpgradedInfoFetchOperation()
        let nonceOperation = createExtrinsicNonceFetchOperation(chain)
        let runtimeVersionOperation = createRuntimeVersionOperation()

        targetOperation.configurationBlock = {
            do {
                let nonce = try nonceOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                let runtimeVersion = try runtimeVersionOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                let upgraded = (try upgradedOperation.targetOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)) ?? false

                let receiverAccountId = try Data(hexString: receiver)
                let senderAccountId = try Data(hexString: sender)
                let genesisHashData = try Data(hexString: chain.genesisHash)

                let additionalParameters = ExtrinsicParameters(
                    nonce: nonce,
                    genesisHash: genesisHashData,
                    specVersion: runtimeVersion.specVersion,
                    transactionVersion: runtimeVersion.transactionVersion,
                    signatureVersion: currentCryptoType.version,
                    moduleIndex: chain.balanceModuleIndex,
                    callIndex: chain.transferCallIndex
                )

                let extrinsicData: Data

                if upgraded {
                    extrinsicData = try ExtrinsicFactory
                        .transferExtrinsic(
                            from: senderAccountId,
                            to: receiverAccountId,
                            amount: amount,
                            additionalParameters: additionalParameters,
                            signer: signer
                        )
                } else {
                    extrinsicData = try ExtrinsicFactoryV27
                        .transferExtrinsic(
                            from: senderAccountId,
                            to: receiverAccountId,
                            amount: amount,
                            additionalParameters: additionalParameters,
                            signer: signer
                        )
                }

                targetOperation.parameters = [extrinsicData.toHex(includePrefix: true)]
            } catch {
                targetOperation.result = .failure(error)
            }
        }

        let dependencies: [Operation] = [nonceOperation, runtimeVersionOperation]
            + upgradedOperation.allOperations

        dependencies.forEach { targetOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: targetOperation,
            dependencies: dependencies
        )
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
