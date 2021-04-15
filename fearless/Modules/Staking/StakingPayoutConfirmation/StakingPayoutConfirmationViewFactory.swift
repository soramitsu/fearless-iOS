import Foundation
import SoraFoundation
import SoraKeystore

final class StakingPayoutConfirmationViewFactory: StakingPayoutConfirmationViewFactoryProtocol {
    static func createView(payouts _: [PayoutInfo]) -> StakingPayoutConfirmationViewProtocol? {
        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let settings = SettingsManager.shared
        let keystore = Keychain()

        let presenter = StakingPayoutConfirmationPresenter()
        let view = StakingPayoutConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        guard let interactor = createInteractor(
            connection: connection,
            settings: settings,
            keystore: keystore,
            payouts: [PayoutInfo]
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
        payouts _: [PayoutInfo]
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
            settings: settings
        )
    }
}
