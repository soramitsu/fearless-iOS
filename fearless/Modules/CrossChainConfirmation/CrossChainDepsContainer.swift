import Foundation
import SoraFoundation
import SSFXCM
import SSFChainRegistry
import SSFModels
import SSFCrypto
import SSFUtils

final class CrossChainDepsContainer {
    enum DepsError: Error {
        case missingChainResponse
    }

    struct CrossChainConfirmationDeps {
        let xcmServices: XcmReadOnlyServices
        let destinationExistentialDepositService: ExistentialDepositServiceProtocol?
        let destinationStorageRequestPerformer: StorageRequestPerformer?
    }

    private var cachedDependencies: [String: CrossChainConfirmationDeps] = [:]
    private let wallet: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol & SSFChainRegistry.ChainRegistryProtocol
    private lazy var operationQueue: OperationQueue = {
        OperationQueue()
    }()

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol & SSFChainRegistry.ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
    }

    // MARK: - Public methods

    func prepareDepsFor(
        originalChainAsset: ChainAsset,
        originalRuntimeMetadataItem: RuntimeMetadataItemProtocol?,
        destChainModel: ChainModel?
    ) throws -> CrossChainConfirmationDeps {
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
                let connection = chainRegistry.getConnection(for: $0)
            else {
                return nil
            }

            return StorageRequestPerformerDefault(runtimeService: runtimeService, connection: connection)
        }

        let deps = CrossChainConfirmationDeps(
            xcmServices: xcmServices,
            destinationExistentialDepositService: existentialDepositService,
            destinationStorageRequestPerformer: storageRequestPerformer
        )

        return deps
    }

    // MARK: - Private methods

    private func createXcmService(
        wallet: MetaAccountModel,
        originalChainAsset: ChainAsset,
        originalRuntimeMetadataItem: RuntimeMetadataItemProtocol?
    ) throws -> XcmReadOnlyServices {
        let request = originalChainAsset.chain.accountRequest()
        guard let response = wallet.fetch(for: request) else {
            throw DepsError.missingChainResponse
        }

        return XcmAssembly.createReadOnlyServices(
            chainId: originalChainAsset.chain.chainId,
            cryptoType: response.cryptoType,
            chainMetadata: originalRuntimeMetadataItem,
            accountId: response.accountId,
            chainType: originalChainAsset.chain.chainBaseType,
            sourceConfig: ApplicationConfig.shared,
            chainRegistry: chainRegistry
        )
    }
}
