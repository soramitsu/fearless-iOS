import Foundation
import SoraFoundation
import SoraKeystore

final class NodeSelectionViewFactory: NodeSelectionViewFactoryProtocol {
    static func createView() -> NodeSelectionViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let view = NodeSelectionViewController(nib: R.nib.selectionListViewController)
        let presenter = NodeSelectionPresenter()
        let interactor = NodeSelectionInteractor(settings: SettingsManager.shared,
                                                 applicationConfig: ApplicationConfig.shared)

        view.localizationManager = localizationManager
        view.listPresenter = presenter
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        interactor.presenter = presenter

        presenter.logger = Logger.shared
        presenter.localizationManager = localizationManager

        return view
    }
}
