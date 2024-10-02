import UIKit
import SoraUI
import SSFModels
import SoraFoundation

final class EcosystemOptionsAssembly {
    static func configureModule(
        ecosystem: Ecosystem,
        wallet: MetaAccountModel,
        chains: [ChainModel],
        moduleOutput: EcosystemOptionsModuleOutput?
    ) -> EcosystemOptionsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = EcosystemOptionsInteractor(
            wallet: wallet,
            keystore: ServiceAssembly.shared.keystore,
            availableExportOptionsProvider: AvailableExportOptionsProvider()
        )
        let router = EcosystemOptionsRouter()

        let presenter = EcosystemOptionsPresenter(
            ecosystem: ecosystem,
            wallet: wallet,
            chains: chains,
            moduleOutput: moduleOutput,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = EcosystemOptionsViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        view.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        view.modalTransitioningFactory = factory

        return (view, presenter)
    }
}
