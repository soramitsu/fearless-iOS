import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct AnalyticsValidatorsViewFactory {
    static func createView() -> AnalyticsValidatorsViewProtocol? {
        let settings = SettingsManager.shared
        let chain = settings.selectedConnection.type.chain
        guard let selectedAddress = settings.selectedAccount?.address else { return nil }
        guard let engine = WebSocketService.shared.connection else { return nil }

        let interactor = createInteractor(selectedAddress: selectedAddress, chain: chain, engine: engine)
        let wireframe = AnalyticsValidatorsWireframe()
        let presenter = createPresenter(interactor: interactor, wireframe: wireframe)
        let view = AnalyticsValidatorsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        selectedAddress: AccountAddress,
        chain: Chain,
        engine: JSONRPCEngine
    ) -> AnalyticsValidatorsInteractor {
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)
        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager,
            logger: logger
        )

        let interactor = AnalyticsValidatorsInteractor(
            selectedAddress: selectedAddress,
            substrateProviderFactory: substrateProviderFactory,
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            identityOperationFactory: identityOperationFactory,
            operationManager: operationManager,
            engine: engine,
            runtimeService: RuntimeRegistryFacade.sharedService,
            storageRequestFactory: requestFactory,
            chain: chain,
            logger: Logger.shared
        )
        return interactor
    }

    private static func createPresenter(
        interactor: AnalyticsValidatorsInteractor,
        wireframe: AnalyticsValidatorsWireframe
    ) -> AnalyticsValidatorsPresenter {
        let settings = SettingsManager.shared
        let selectedType = settings.selectedConnection.type
        let chain = selectedType.chain

        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: selectedType,
            limit: StakingConstants.maxAmount
        )
        let viewModelFactory = AnalyticsValidatorsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            chain: chain
        )

        let presenter = AnalyticsValidatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
        return presenter
    }
}
