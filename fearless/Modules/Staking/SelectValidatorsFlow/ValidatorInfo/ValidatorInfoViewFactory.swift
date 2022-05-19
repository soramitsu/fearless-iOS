import Foundation
import FearlessUtils
import SoraKeystore
import SoraFoundation

final class ValidatorInfoViewFactory {
    private static func createContainer(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> ValidatorInfoDependencyContainer? {
        switch flow {
        case let .relaychain(validatorInfo, address):
            let storageRequestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManagerFacade.sharedManager
            )

            let chainRegistry = ChainRegistryFacade.sharedRegistry

            guard
                let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
                let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
                return nil
            }

            let validatorOperationFactory = RelaychainValidatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                eraValidatorService: EraValidatorFacade.sharedService,
                rewardService: RewardCalculatorFacade.sharedService,
                storageRequestFactory: storageRequestFactory,
                runtimeService: runtimeService,
                engine: connection,
                identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
            )

            let balanceViewModelFactory = BalanceViewModelFactory(
                targetAssetInfo: chainAsset.asset.displayInfo,
                limit: StakingConstants.maxAmount
            )

            let viewModelState = ValidatorInfoRelaychainViewModelState()
            let strategy = ValidatorInfoRelaychainStrategy(
                validatorInfo: validatorInfo,
                accountAddress: address,
                wallet: wallet,
                chainAsset: chainAsset,
                validatorOperationFactory: validatorOperationFactory,
                operationManager: OperationManagerFacade.sharedManager,
                output: viewModelState
            )
            let viewModelFactory = ValidatorInfoRelaychainViewModelFactory(
                iconGenerator: PolkadotIconGenerator(),
                balanceViewModelFactory: balanceViewModelFactory
            )

            return ValidatorInfoDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case .parachain:
            let viewModelState = ValidatorInfoParachainViewModelState()
            let strategy = ValidatorInfoParachainStrategy()
            let viewModelFactory = ValidatorInfoParachainViewModelFactory()

            return ValidatorInfoDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}

extension ValidatorInfoViewFactory: ValidatorInfoViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: ValidatorInfoFlow
    ) -> ValidatorInfoViewProtocol? {
        guard let container = createContainer(flow: flow, chainAsset: chainAsset, wallet: wallet) else {
            return nil
        }

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

        let interactor = ValidatorInfoInteractorBase(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            asset: chainAsset.asset,
            strategy: container.strategy
        )

        let localizationManager = LocalizationManager.shared

        let wireframe = ValidatorInfoWireframe()

        let presenter = ValidatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            chainAsset: chainAsset,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ValidatorInfoViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
