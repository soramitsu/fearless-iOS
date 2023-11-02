import UIKit
import SoraFoundation

final class WalletConnectConfirmationAssembly {
    static func configureModule(
        inputData: WalletConnectConfirmationInputData
    ) -> WalletConnectConfirmationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = WalletConnectConfirmationInteractor(
            walletConnect: WalletConnectServiceImpl.shared,
            inputData: inputData,
            signer: WalletConnectSignerImpl(wallet: inputData.wallet)
        )
        let router = WalletConnectConfirmationRouter()

        let presenter = WalletConnectConfirmationPresenter(
            inputData: inputData,
            viewModelFactory: WalletConnectConfirmationViewModelFactoryImpl(inputData: inputData),
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = WalletConnectConfirmationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
