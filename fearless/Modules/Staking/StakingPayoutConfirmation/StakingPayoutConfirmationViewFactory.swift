import Foundation
import SoraFoundation
import SoraKeystore

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

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: networkType,
            limit: StakingConstants.maxAmount
        )

        let presenter = StakingPayoutConfirmationPresenter(
            balanceViewModelFactory: balanceViewModelFactory, asset: asset,
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
        guard let selectedAccount = settings.selectedAccount
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicService = ExtrinsicService(
            address: selectedAccount.address,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: RuntimeRegistryFacade.sharedService,
            engine: connection,
            operationManager: operationManager
        )

        let signer = SigningWrapper(
            keystore: keystore,
            settings: settings
        )

        return StakingPayoutConfirmationInteractor(
            extrinsicService: extrinsicService,
            signer: signer,
            settings: settings,
            payouts: payouts
        )
    }
}
