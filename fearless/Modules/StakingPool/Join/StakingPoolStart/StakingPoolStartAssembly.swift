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
            collatorOperationFactory: nil
        ) else {
            return nil
        }

        let stakingDurationOperationFactory = StakingDurationOperationFactory()

        let interactor = StakingPoolStartInteractor(
            operationManager: operationManager,
            runtimeService: runtimeService,
            stakingDurationOperationFactory: stakingDurationOperationFactory,
            rewardService: rewardCalculatorService
        )
        let router = StakingPoolStartRouter()
        let viewModelFactory = StakingPoolStartViewModelFactory(chainAsset: chainAsset)

        let presenter = StakingPoolStartPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory,
            wallet: wallet,
            chainAsset: chainAsset,
            amount: amount
        )

        let view = StakingPoolStartViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
