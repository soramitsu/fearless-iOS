import Foundation
import SSFUtils
import SoraKeystore
import SoraFoundation
import SSFModels

final class ValidatorInfoViewFactory {
    // swiftlint:disable function_body_length
    private static func createContainer(
        flow: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> ValidatorInfoDependencyContainer? {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,

            selectedMetaAccount: wallet
        )

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

            let serviceFactory = StakingServiceFactory(
                chainRegisty: chainRegistry,
                storageFacade: SubstrateDataStorageFacade.shared,
                eventCenter: EventCenter.shared,
                operationManager: OperationManagerFacade.sharedManager
            )

            guard
                let eraValidatorService = try? serviceFactory.createEraValidatorService(
                    for: chainAsset.chain
                ) else {
                return nil
            }

            let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)

            let collatorOperationFactory = ParachainCollatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                storageRequestFactory: storageRequestFactory,
                identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
                subqueryOperationFactory: rewardOperationFactory,
                chainRegistry: chainRegistry
            )

            guard let rewardService = try? serviceFactory.createRewardCalculatorService(
                for: chainAsset,
                assetPrecision: Int16(chainAsset.asset.precision),
                validatorService: eraValidatorService,
                collatorOperationFactory: collatorOperationFactory,
                wallet: wallet
            ) else {
                return nil
            }

            eraValidatorService.setup()
            rewardService.setup()

            let validatorOperationFactory = RelaychainValidatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                eraValidatorService: eraValidatorService,
                rewardService: rewardService,
                storageRequestFactory: storageRequestFactory,
                identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
                chainRegistry: chainRegistry
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
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain),
                balanceViewModelFactory: balanceViewModelFactory
            )

            return ValidatorInfoDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(candidate):
            let chainRegistry = ChainRegistryFacade.sharedRegistry

            guard
                let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
                let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
                return nil
            }

            let storageRequestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManagerFacade.sharedManager
            )

            let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)

            let operationFactory = ParachainCollatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                storageRequestFactory: storageRequestFactory,
                identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
                subqueryOperationFactory: rewardOperationFactory,
                chainRegistry: chainRegistry
            )
            let viewModelState = ValidatorInfoParachainViewModelState(collatorInfo: candidate)
            let strategy = ValidatorInfoParachainStrategy(
                collatorId: candidate.owner,
                operationFactory: operationFactory,
                operationManager: OperationManagerFacade.sharedManager,
                output: viewModelState
            )
            let viewModelFactory = ValidatorInfoParachainViewModelFactory(
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain),
                balanceViewModelFactory: balanceViewModelFactory,
                chainAsset: chainAsset
            )

            return ValidatorInfoDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .pool(validatorInfo, address):
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

            let serviceFactory = StakingServiceFactory(
                chainRegisty: chainRegistry,
                storageFacade: SubstrateDataStorageFacade.shared,
                eventCenter: EventCenter.shared,
                operationManager: OperationManagerFacade.sharedManager
            )

            guard
                let eraValidatorService = try? serviceFactory.createEraValidatorService(
                    for: chainAsset.chain
                ) else {
                return nil
            }

            let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)

            let collatorOperationFactory = ParachainCollatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                storageRequestFactory: storageRequestFactory,
                identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
                subqueryOperationFactory: rewardOperationFactory,
                chainRegistry: chainRegistry
            )

            guard let rewardService = try? serviceFactory.createRewardCalculatorService(
                for: chainAsset,
                assetPrecision: Int16(chainAsset.asset.precision),
                validatorService: eraValidatorService,
                collatorOperationFactory: collatorOperationFactory,
                wallet: wallet
            ) else {
                return nil
            }

            eraValidatorService.setup()
            rewardService.setup()

            let validatorOperationFactory = RelaychainValidatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                eraValidatorService: eraValidatorService,
                rewardService: rewardService,
                storageRequestFactory: storageRequestFactory,
                identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
                chainRegistry: chainRegistry
            )

            let viewModelState = ValidatorInfoPoolViewModelState()
            let strategy = ValidatorInfoPoolStrategy(
                validatorInfo: validatorInfo,
                accountAddress: address,
                wallet: wallet,
                chainAsset: chainAsset,
                validatorOperationFactory: validatorOperationFactory,
                operationManager: OperationManagerFacade.sharedManager,
                output: viewModelState
            )
            let viewModelFactory = ValidatorInfoPoolViewModelFactory(
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain),
                balanceViewModelFactory: balanceViewModelFactory
            )

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
