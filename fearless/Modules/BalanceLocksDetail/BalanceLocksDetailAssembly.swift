import UIKit
import SoraFoundation
import SSFModels
import SSFUtils

final class BalanceLocksDetailAssembly {
    static func configureModule(chainAsset: ChainAsset, wallet: MetaAccountModel) -> BalanceLocksDetailModuleCreationResult? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
        else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let operationManager = OperationManagerFacade.sharedManager

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let storageRequestPerformer = StorageRequestPerformerImpl(
            runtimeService: runtimeService,
            connection: connection,
            operationManager: operationManager,
            storageRequestFactory: storageRequestFactory
        )
        let interactor = BalanceLocksDetailInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            storageRequestPerformer: storageRequestPerformer
        )
        let router = BalanceLocksDetailRouter()

        let presenter = BalanceLocksDetailPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = BalanceLocksDetailViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
