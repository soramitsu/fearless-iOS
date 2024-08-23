import UIKit
import SoraFoundation

final class WalletConnectConfirmationAssembly {
    static func configureModule(
        inputData: WalletConnectConfirmationInputData
    ) -> WalletConnectConfirmationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        guard
            let accountResponse = inputData.wallet.fetch(for: inputData.chain.accountRequest()),
            let bocFactory = try? ServiceAssembly.shared.tonBocFactory(
                metaId: inputData.wallet.metaId,
                accountResponse: accountResponse
            )
        else {
            return nil
        }
        let interactor = WalletConnectConfirmationInteractor(
            walletConnect: WalletConnectServiceImpl.shared,
            inputData: inputData,
            signer: WalletConnectSignerImpl(wallet: inputData.wallet),
            tonConnectService: ServiceAssembly.shared.tonConnectService()
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
