import Foundation
import SoraFoundation
import SSFXCM
import SSFModels
import SSFCrypto
import SoraKeystore
import SSFUtils

final class CrossChainDepsContainer {
    enum DepsError: Error {
        case missingChainResponse
    }

    struct CrossChainConfirmationDeps {
        let xcmServices: XcmExtrinsicServices
        let destinationExistentialDepositService: ExistentialDepositServiceProtocol?
        let destinationStorageRequestPerformer: StorageRequestPerformer?
    }

    private var cachedDependencies: [String: CrossChainConfirmationDeps] = [:]
    private let wallet: MetaAccountModel
    private lazy var operationQueue: OperationQueue = {
        OperationQueue()
    }()

    init(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    // MARK: - Public methods

    func prepareDepsFor(
        originalChainAsset: ChainAsset,
        originalRuntimeMetadataItem: RuntimeMetadataItemProtocol?,
        destChainModel: ChainModel?
    ) throws -> CrossChainConfirmationDeps {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let xcmServices = try createXcmService(
            wallet: wallet,
            originalChainAsset: originalChainAsset,
            originalRuntimeMetadataItem: originalRuntimeMetadataItem
        )
        let existentialDepositService = (destChainModel?.chainId).map {
            ExistentialDepositService(
                operationManager: OperationManagerFacade.sharedManager,
                chainRegistry: chainRegistry,
                chainId: $0
            )
        }
        let storageRequestPerformer: StorageRequestPerformer? = (destChainModel?.chainId).flatMap {
            guard
                let runtimeService = chainRegistry.getRuntimeProvider(for: $0),
                let connection = chainRegistry.getConnection(for: $0) else {
                return nil
            }

            return StorageRequestPerformerDefault(runtimeService: runtimeService, connection: connection)
        }

        let deps = CrossChainConfirmationDeps(
            xcmServices: xcmServices,
            destinationExistentialDepositService: existentialDepositService,
            destinationStorageRequestPerformer: storageRequestPerformer
        )

        cachedDependencies[originalChainAsset.chain.chainId] = deps

        return deps
    }

    // MARK: - Private methods

    private func createXcmService(
        wallet: MetaAccountModel,
        originalChainAsset: ChainAsset,
        originalRuntimeMetadataItem: RuntimeMetadataItemProtocol?
    ) throws -> XcmExtrinsicServices {
        let request = originalChainAsset.chain.accountRequest()
        guard let response = wallet.fetch(for: request) else {
            throw DepsError.missingChainResponse
        }

        let cryptoType = response.cryptoType
        let accountId = response.accountId

        let secretKeyData = try fetchSecretKey(
            for: originalChainAsset.chain,
            metaId: wallet.metaId,
            accountResponse: response
        )

        let signingWrapperData = XcmAssembly.SigningWrapperData(
            publicKeyData: response.publicKey,
            secretKeyData: secretKeyData
        )

        let fromChainData = XcmAssembly.FromChainData(
            chainId: originalChainAsset.chain.chainId,
            cryptoType: SFCryptoType(utilsType: cryptoType.utilsType, isEthereum: response.isEthereumBased),
            chainMetadata: originalRuntimeMetadataItem,
            accountId: accountId,
            signingWrapperData: signingWrapperData
        )

        let sourceConfig = ApplicationConfig.shared
        let services = XcmAssembly.createExtrincisServices(
            fromChainData: fromChainData,
            sourceConfig: sourceConfig
        )

        return services
    }

    private func fetchSecretKey(
        for chain: ChainModel,
        metaId: String,
        accountResponse: ChainAccountResponse
    ) throws -> Data {
        let accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        let tag: String = chain.isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)

        let keystore = Keychain()
        let secretKey = try keystore.fetchKey(for: tag)
        return secretKey
    }
}
