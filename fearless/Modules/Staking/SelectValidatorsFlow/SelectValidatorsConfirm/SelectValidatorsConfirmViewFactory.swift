import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import FearlessUtils

final class SelectValidatorsConfirmViewFactory: SelectValidatorsConfirmViewFactoryProtocol {
    static func createInitiatedBondingView(
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        for state: PreparedNomination<InitiatedBonding>
    ) -> SelectValidatorsConfirmViewProtocol? {
        let keystore = Keychain()

        guard let interactor = createInitiatedBondingInteractor(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset,
            nomination: state,
            keystore: keystore
        ) else {
            return nil
        }

        let wireframe = SelectValidatorsConfirmWireframe()

        return createView(
            asset: asset,
            chain: chain,
            for: interactor,
            wireframe: wireframe
        )
    }

    static func createChangeTargetsView(
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        for state: PreparedNomination<ExistingBonding>
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = SelectValidatorsConfirmWireframe()
        return createExistingBondingView(
            selectedAccount: selectedAccount,
            asset: asset,
            chain: chain,
            for: state,
            wireframe: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        for state: PreparedNomination<ExistingBonding>
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = YourValidatorList.SelectValidatorsConfirmWireframe()
        return createExistingBondingView(
            selectedAccount: selectedAccount,
            asset: asset,
            chain: chain,
            for: state,
            wireframe: wireframe
        )
    }

    private static func createExistingBondingView(
        selectedAccount: MetaAccountModel,
        asset: AssetModel,
        chain: ChainModel,
        for state: PreparedNomination<ExistingBonding>,
        wireframe: SelectValidatorsConfirmWireframeProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        let keystore = Keychain()

        guard let interactor = createChangeTargetsInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            state,
            keystore: keystore
        ) else {
            return nil
        }

        return createView(
            asset: asset,
            chain: chain,
            for: interactor,
            wireframe: wireframe
        )
    }

    private static func createView(
        asset: AssetModel,
        chain: ChainModel,
        for interactor: SelectValidatorsConfirmInteractorBase,
        wireframe: SelectValidatorsConfirmWireframeProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        let confirmViewModelFactory = SelectValidatorsConfirmViewModelFactory()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            priceAssetInfo: AssetBalanceDisplayInfo.usd(),
            limit: StakingConstants.maxAmount
        )

        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            priceAssetInfo: AssetBalanceDisplayInfo.usd(),
            formatterFactory: AssetBalanceFormatterFactory(),
            limit: StakingConstants.maxAmount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: errorBalanceViewModelFactory
        )

        let presenter = SelectValidatorsConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmationViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            asset: asset,
            chain: chain,
            logger: Logger.shared
        )

        let view = SelectValidatorsConfirmViewController(
            presenter: presenter,
            quantityFormatter: .quantity,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInitiatedBondingInteractor(
        selectedAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel,
        nomination: PreparedNomination<InitiatedBonding>,
        keystore: KeystoreProtocol
    ) -> SelectValidatorsConfirmInteractorBase? {
        let operationManager = OperationManagerFacade.sharedManager

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        guard let accountResponse = selectedAccount.fetch(for: chain.accountRequest()) else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let signer = SigningWrapper(
            keystore: keystore,
            metaId:
            selectedAccount.metaId,
            accountResponse: accountResponse
        )

        let logger = Logger.shared
        let storageFacade = SubstrateDataStorageFacade.shared

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
        let priceLocalSubcriptionFactory = PriceProviderFactory(storageFacade: storageFacade)

        return InitiatedBondingConfirmInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: StakingDurationOperationFactory(),
            operationManager: operationManager,
            signer: signer,
            nomination: nomination,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubcriptionFactory
        )
    }

    private static func createChangeTargetsInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        _ nomination: PreparedNomination<ExistingBonding>,
        keystore: KeystoreProtocol
    ) -> SelectValidatorsConfirmInteractorBase? {
        let operationManager = OperationManagerFacade.sharedManager

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        guard let accountResponse = selectedAccount.fetch(for: chain.accountRequest()) else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let signer = SigningWrapper(
            keystore: keystore,
            metaId:
            selectedAccount.metaId,
            accountResponse: accountResponse
        )

        let logger = Logger.shared
        let storageFacade = SubstrateDataStorageFacade.shared

        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
        let priceLocalSubcriptionFactory = PriceProviderFactory(storageFacade: storageFacade)

        return ChangeTargetsConfirmInteractor(
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: StakingDurationOperationFactory(),
            operationManager: operationManager,
            signer: signer,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            nomination: nomination,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubcriptionFactory
        )
    }
}
