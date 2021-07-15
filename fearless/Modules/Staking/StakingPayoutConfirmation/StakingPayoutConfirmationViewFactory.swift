import Foundation
import SoraFoundation
import SoraKeystore
import FearlessUtils
import RobinHood

final class StakingPayoutConfirmationViewFactory: StakingPayoutConfirmationViewFactoryProtocol {
    static func createView(payouts: [PayoutInfo]) -> StakingPayoutConfirmationViewProtocol? {
        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let settings = SettingsManager.shared
        let keystore = Keychain()

        let networkType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)
        let chain = settings.selectedConnection.type.chain

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )

        let payoutConfirmViewModelFactory = StakingPayoutConfirmViewModelFactory(
            asset: asset,
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = StakingPayoutConfirmationPresenter(
            balanceViewModelFactory: balanceViewModelFactory,
            payoutConfirmViewModelFactory: payoutConfirmViewModelFactory,
            chain: chain,
            asset: asset,
            logger: Logger.shared
        )

        let view = StakingPayoutConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        guard let interactor = createInteractor(
            connection: connection,
            settings: settings,
            keystore: keystore,
            payouts: payouts
        ) else {
            return nil
        }

        let wireframe = StakingPayoutConfirmationWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        connection: JSONRPCEngine,
        settings: SettingsManagerProtocol,
        keystore: KeystoreProtocol,
        payouts: [PayoutInfo]
    ) -> StakingPayoutConfirmationInteractor? {
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let runtimeService = RuntimeRegistryFacade.sharedService

        let asset = primitiveFactory.createAssetForAddressType(settings.selectedConnection.type)

        guard let selectedAccount = settings.selectedAccount,
              let assetId = WalletAssetId(rawValue: asset.identifier),
              let chain = assetId.chain
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicService = ExtrinsicService(
            address: selectedAccount.address,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let signer = SigningWrapper(
            keystore: keystore,
            settings: settings
        )

        let singleValueProviderFactory = SingleValueProviderFactory.shared

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let feeProxy = ExtrinsicFeeProxy()

        return StakingPayoutConfirmationInteractor(
            singleValueProviderFactory: singleValueProviderFactory,
            substrateProviderFactory: substrateProviderFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            runtimeService: runtimeService,
            signer: signer,
            accountRepository: AnyDataProviderRepository(accountRepository),
            operationManager: operationManager,
            settings: settings,
            logger: Logger.shared,
            payouts: payouts,
            chain: chain,
            assetId: assetId
        )
    }
}
