import Foundation
import CommonWallet

final class WalletHistoryFilterEditor: HistoryFilterEditing {
    func startEditing(
        filter _: WalletHistoryRequest,
        with _: [WalletAsset],
        commandFactory: WalletCommandFactoryProtocol,
        notifying _: HistoryFilterEditingDelegate?
    ) {
        guard let view = WalletHistoryFilterViewFactory.createView() else {
            return
        }

        let command = commandFactory.preparePresentationCommand(for: view.controller)
        command.presentationStyle = .modal(inNavigation: true)
        try? command.execute()
    }
}
