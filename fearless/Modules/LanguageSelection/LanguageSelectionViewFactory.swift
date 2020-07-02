import Foundation
import SoraFoundation

final class LanguageSelectionViewFactory: LanguageSelectionViewFactoryProtocol {
    static func createView() -> LanguageSelectionViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let view = LanguageSelectionViewController(nib: R.nib.selectionListViewController)
        let presenter = LanguageSelectionPresenter()
        let interactor = LanguageSelectionInteractor(localizationManager: localizationManager)
        let wireframe = LanguageSelectionWireframe()

        view.localizationManager = localizationManager
        view.listPresenter = presenter
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.logger = Logger.shared
        presenter.localizationManager = localizationManager

        interactor.logger = Logger.shared

        return view
    }
}
