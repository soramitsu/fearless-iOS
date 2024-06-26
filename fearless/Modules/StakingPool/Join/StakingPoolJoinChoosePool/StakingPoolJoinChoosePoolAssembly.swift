import UIKit
import SoraFoundation
import SSFUtils
import SSFModels

final class StakingPoolJoinChoosePoolAssembly {
    static func configureModule(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        inputAmount: Decimal
    ) -> StakingPoolJoinChoosePoolModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let operationManager = OperationManagerFacade.sharedManager
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let stakingPoolOperationFactory = StakingPoolOperationFactory(
            chainAsset: chainAsset,
            storageRequestFactory: requestFactory,
            chainRegistry: chainRegistry
        )
        let interactor = StakingPoolJoinChoosePoolInteractor(
            stakingPoolOperationFactory: stakingPoolOperationFactory,
            operationManager: operationManager
        )
        let router = StakingPoolJoinChoosePoolRouter()
        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = StakingPoolJoinChoosePoolViewModelFactory(
            chainAsset: chainAsset,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory
        )
        let presenter = StakingPoolJoinChoosePoolPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory,
            inputAmount: inputAmount,
            chainAsset: chainAsset,
            wallet: wallet,
            filterFactory: TitleSwitchTableViewCellModelFactory()
        )

        let view = StakingPoolJoinChoosePoolViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
