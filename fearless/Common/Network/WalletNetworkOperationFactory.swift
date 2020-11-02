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

    init(engine: JSONRPCEngine,
         accountSettings: WalletAccountSettingsProtocol,
         cryptoType: CryptoType,
         accountSigner: IRSignatureCreatorProtocol,
         dummySigner: IRSignatureCreatorProtocol) {
        self.engine = engine
        self.accountSettings = accountSettings
        self.cryptoType = cryptoType
        self.accountSigner = accountSigner
        self.dummySigner = dummySigner
    }

    func createGenisisHashOperation() -> BaseOperation<String> {
        createBlockHashOperation(0)
    }

    func createBlockHashOperation(_ block: UInt32) -> BaseOperation<String> {
        var currentBlock = block
        let param = Data(Data(bytes: &currentBlock, count: MemoryLayout<UInt32>.size).reversed())
            .toHex(includePrefix: true)

        return JSONRPCListOperation<String>(engine: engine,
                                            method: RPCMethod.getBlockHash,
                                            parameters: [param])
    }

    func createAccountInfoFetchOperation(_ accountId: Data? = nil)
        -> BaseOperation<JSONScaleDecodable<AccountInfo>> {
        do {
            let identifier = try (accountId ?? Data(hexString: accountSettings.accountId))

            let key = try StorageKeyFactory()
                .createStorageKey(moduleName: "System",
                                  serviceName: "Account",
                                  identifier: identifier,
                                  hasher: Blake128Concat()).toHex(includePrefix: true)

            return JSONRPCListOperation<JSONScaleDecodable<AccountInfo>>(engine: engine,
                                                                         method: RPCMethod.getStorage,
                                                                         parameters: [key])
        } catch {
            return createBaseOperation(result: .failure(error))
        }
    }

    func createRuntimeVersionOperation() -> BaseOperation<RuntimeVersion> {
        return JSONRPCListOperation(engine: engine, method: RPCMethod.getRuntimeVersion)
    }

    func setupTransferExtrinsic<T>(_ targetOperation: JSONRPCListOperation<T>,
                                   amount: BigUInt,
                                   receiver: String,
                                   chain: Chain,
                                   signer: IRSignatureCreatorProtocol) -> CompoundOperationWrapper<T> {
        let accountInfoOperation = createAccountInfoFetchOperation()
        let runtimeVersionOperation = createRuntimeVersionOperation()

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
                                                               signatureVersion: currentCryptoType.version,
                                                               moduleIndex: chain.balanceModuleIndex,
                                                               callIndex: chain.transferCallIndex)

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
