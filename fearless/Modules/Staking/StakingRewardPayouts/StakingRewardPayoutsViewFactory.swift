import Foundation
import SoraKeystore

final class StakingRewardPayoutsViewFactory: StakingRewardPayoutsViewFactoryProtocol {
    static func createView() -> StakingRewardPayoutsViewProtocol? {
        guard let connection = WebSocketService.shared.connection else { return nil }

        let chain = Chain.westend
        let selectedAccount = "5DEwU2U97RnBHCpfwHMDfJC7pqAdfWaPFib9wiZcr2ephSfT"
        let storageFacade = SubstrateDataStorageFacade.shared
        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let settings = SettingsManager.shared
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )
        let presenter = StakingRewardPayoutsPresenter(
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let view = StakingRewardPayoutsViewController(presenter: presenter)

        let providerFactory = SubstrateDataProviderFactory(
            facade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let payoutService = PayoutRewardsService(
            selectedAccountAddress: selectedAccount,
            chain: chain,
            runtimeCodingService: RuntimeRegistryFacade.sharedService,
            engine: connection,
            operationManager: operationManager,
            providerFactory: providerFactory,
            subscanOperationFactory: SubscanOperationFactory()
        )
        let interactor = StakingRewardPayoutsInteractor(payoutService: payoutService)
        let wireframe = StakingRewardPayoutsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
