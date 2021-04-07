import Foundation
import SoraFoundation

final class WalletHistoryFilterViewFactory: WalletHistoryFilterViewFactoryProtocol {
    static func createView() -> WalletHistoryFilterViewProtocol? {
        let presenter = WalletHistoryFilterPresenter()
        let view = WalletHistoryFilterViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let interactor = WalletHistoryFilterInteractor()
        let wireframe = WalletHistoryFilterWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
