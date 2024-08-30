import UIKit
import SoraFoundation
import SSFModels

final class TonWebBridgeAssembly {
    static func configureModule(
        for dapp: TonDapp,
        wallet: MetaAccountModel,
        moduleOutput: TonWebBridgeModuleOutput?
    ) -> TonWebBridgeModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = TonWebBridgeInteractor(
            tonConnectService: ServiceAssembly.shared.tonConnectService(),
            chainRepository: ServiceAssembly.shared.asyncChainModelRepository()
        )
        let router = TonWebBridgeRouter()

        let presenter = TonWebBridgePresenter(
            dapp: dapp,
            wallet: wallet,
            messageBuilder: TonConnectMessageBuilderImpl(),
            interactor: interactor,
            router: router,
            logger: ServiceAssembly.shared.logger,
            moduleOutput: moduleOutput,
            localizationManager: localizationManager
        )

        let view = TonWebBridgeViewController(
            title: dapp.name,
            initialUrl: dapp.url,
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
