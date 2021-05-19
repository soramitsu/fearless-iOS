import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation

final class StakingAmountViewFactory: StakingAmountViewFactoryProtocol {
    static func createView(with amount: Decimal?) -> StakingAmountViewProtocol? {
        let settings = SettingsManager.shared

        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        guard let presenter = createPresenter(
            amount: amount,
            settings: settings
        ) else {
            return nil
        }

        guard let interactor = createInteractor(
            connection: connection,
            settings: settings
        ) else {
            return nil
        }

        let view = StakingAmountViewController(nib: R.nib.stakingAmountViewController)
        let wireframe = StakingAmountWireframe()

        view.uiFactory = UIFactory()
        view.localizationManager = LocalizationManager.shared

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        amount: Decimal?,
        settings: SettingsManagerProtocol
    ) -> StakingAmountPresenter? {
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        guard let selectedAccount = settings.selectedAccount else {
            return nil
        }

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )

        let selectedConnectionType = settings.selectedConnection.type
        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount,
            formatterFactory: AmountFormatterFactory(assetPrecision: Int(selectedConnectionType.precision))
        )

        let rewardDestViewModelFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = StakingAmountPresenter(
            amount: amount,
            asset: asset,
            selectedAccount: selectedAccount,
            rewardDestViewModelFactory: rewardDestViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            errorBalanceViewModelFactory: errorBalanceViewModelFactory,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        return presenter
    }

    private static func createInteractor(
        connection: JSONRPCEngine,
        settings: SettingsManagerProtocol
    ) -> StakingAmountInteractor? {
        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(networkType)

        guard let selectedAccount = settings.selectedAccount,
              let assetId = WalletAssetId(rawValue: asset.identifier)
        else {
            return nil
        }

        let runtimeService = RuntimeRegistryFacade.sharedService
        let operationManager = OperationManagerFacade.sharedManager

        let providerFactory = SingleValueProviderFactory.shared
        guard let balanceProvider = try? providerFactory
            .getAccountProvider(
                for: selectedAccount.address,
                runtimeService: runtimeService
            )
        else {
            return nil
        }

        let facade = UserDataStorageFacade.shared

        let filter = NSPredicate.filterAccountBy(networkType: networkType)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            facade.createRepository(
                filter: filter,
                sortDescriptors: [.accountsByOrder]
            )

        let extrinsicService = ExtrinsicService(
            address: selectedAccount.address,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let priceProvider = providerFactory.getPriceProvider(for: assetId)

        let interactor = StakingAmountInteractor(
            repository: AnyDataProviderRepository(accountRepository),
            priceProvider: AnySingleValueProvider(priceProvider),
            balanceProvider: AnyDataProvider(balanceProvider),
            extrinsicService: extrinsicService,
            rewardService: RewardCalculatorFacade.sharedService,
            runtimeService: runtimeService,
            operationManager: operationManager
        )

        return interactor
    }
}
