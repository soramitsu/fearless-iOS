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

        let wireframe = WalletHistoryFilterWireframe(
            originalRequest: request,
            commandFactory: commandFactory,
            delegate: delegate
        )

        presenter.view = view
        presenter.wireframe = wireframe

        return view
    }
}
