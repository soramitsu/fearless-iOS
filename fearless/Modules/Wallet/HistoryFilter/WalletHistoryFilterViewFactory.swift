import Foundation
import SoraFoundation
import CommonWallet

final class WalletHistoryFilterViewFactory: WalletHistoryFilterViewFactoryProtocol {
    static func createView(
        request: WalletHistoryRequest,
        commandFactory: WalletCommandFactoryProtocol,
        delegate: HistoryFilterEditingDelegate?
    ) -> WalletHistoryFilterViewProtocol? {
        let filter = WalletHistoryFilter(string: request.filter)

        let presenter = WalletHistoryFilterPresenter(filter: filter)
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
