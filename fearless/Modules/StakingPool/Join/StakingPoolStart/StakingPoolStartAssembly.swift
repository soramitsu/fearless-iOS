import UIKit
import SoraFoundation
import FearlessUtils

final class StakingPoolStartAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        amount: Decimal?
    ) -> StakingPoolStartModuleCreationResult? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.setupConnection(for: chainAsset.chain),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let localizationManager = LocalizationManager.shared

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: substrateStorageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        guard let eraValidatorService = try? serviceFactory.createEraValidatorService(
            for: chainAsset.chain
        ) else {
            return nil
        }

        guard let rewardCalculatorService = try? serviceFactory.createRewardCalculatorService(
            for: chainAsset,
            assetPrecision: Int16(chainAsset.asset.precision),
            validatorService: eraValidatorService,
            collatorOperationFactory: nil,
            wallet: wallet
        ) else {
            return nil
        }

        let stakingDurationOperationFactory = StakingDurationOperationFactory()
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let stakingPoolOperationFactory = StakingPoolOperationFactory(
            chainAsset: chainAsset,
            storageRequestFactory: requestFactory,
            runtimeService: runtimeService,
            engine: connection
        )

        let interactor = StakingPoolStartInteractor(
            operationManager: operationManager,
            runtimeService: runtimeService,
            stakingDurationOperationFactory: stakingDurationOperationFactory,
            rewardService: rewardCalculatorService,
            stakingPoolOperationFactory: stakingPoolOperationFactory
        )
        let router = StakingPoolStartRouter()
        let viewModelFactory = StakingPoolStartViewModelFactory(chainAsset: chainAsset)

        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: router,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = StakingPoolStartPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory,
            wallet: wallet,
            chainAsset: chainAsset,
            amount: amount,
            logger: Logger.shared,
            dataValidatingFactory: dataValidatingFactory
        )

        let view = StakingPoolStartViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
