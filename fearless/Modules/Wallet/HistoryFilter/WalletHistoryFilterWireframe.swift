import Foundation
import CommonWallet

final class WalletHistoryFilterWireframe: WalletHistoryFilterWireframeProtocol {
    let commandFactory: WalletCommandFactoryProtocol
    weak var delegate: HistoryFilterEditingDelegate?
    let originalRequest: WalletHistoryRequest

    init(
        originalRequest: WalletHistoryRequest,
        commandFactory: WalletCommandFactoryProtocol,
        delegate: HistoryFilterEditingDelegate?
    ) {
        self.originalRequest = originalRequest
        self.commandFactory = commandFactory
        self.delegate = delegate
    }

    func proceed(from _: WalletHistoryFilterViewProtocol?, applying filter: WalletHistoryFilter) {
        var newRequest = WalletHistoryRequest(assets: originalRequest.assets ?? [])
        newRequest.filter = (filter != .all) ? String(filter.rawValue) : nil

        delegate?.historyFilterDidEdit(request: newRequest)

        let command = commandFactory.prepareHideCommand(with: .dismiss)
        try? command.execute()
    }
}
