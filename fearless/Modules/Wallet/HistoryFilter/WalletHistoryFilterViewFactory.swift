import Foundation
import SoraFoundation
import CommonWallet

final class WalletHistoryFilterViewFactory: WalletHistoryFilterViewFactoryProtocol {
    static func createView(
        commandFactory: WalletCommandFactoryProtocol,
        delegate: HistoryFilterEditingDelegate?
    ) -> WalletHistoryFilterViewProtocol? {
        let presenter = WalletHistoryFilterPresenter()
        let view = WalletHistoryFilterViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let interactor = WalletHistoryFilterInteractor()
        let wireframe = WalletHistoryFilterWireframe(commandFactory: commandFactory, delegate: delegate)

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
