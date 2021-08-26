import Foundation
import SoraKeystore
import RobinHood
import SoraFoundation
import FearlessUtils

final class StakingAmountViewFactory: StakingAmountViewFactoryProtocol {
    static func createView(with amount: Decimal?) -> StakingAmountViewProtocol? {
        let settings = SettingsManager.shared

        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let view = StakingAmountViewController(nib: R.nib.stakingAmountViewController)
        let wireframe = StakingAmountWireframe()

        guard let presenter = createPresenter(
            view: view,
            wireframe: wireframe,
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

        view.uiFactory = UIFactory()
        view.localizationManager = LocalizationManager.shared

        presenter.interactor = interactor
        interactor.presenter = presenter
        view.presenter = presenter

        return view
    }

    private static func createPresenter(
        view: StakingAmountViewProtocol,
        wireframe: StakingAmountWireframeProtocol,
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

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: errorBalanceViewModelFactory
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
            dataValidatingFactory: dataValidatingFactory,
            applicationConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe
        dataValidatingFactory.view = view

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

        let interactor = StakingAmountInteractor(
            accountAddress: selectedAccount.address,
            repository: AnyDataProviderRepository(accountRepository),
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            extrinsicService: extrinsicService,
            rewardService: RewardCalculatorFacade.sharedService,
            runtimeService: runtimeService,
            operationManager: operationManager,
            chain: networkType.chain,
            assetId: assetId
        )

        return interactor
    }
}
