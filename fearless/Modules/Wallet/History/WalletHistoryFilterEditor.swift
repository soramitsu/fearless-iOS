import Foundation
import CommonWallet

final class WalletHistoryFilterEditor: HistoryFilterEditing {
    func startEditing(
        filter: WalletHistoryRequest,
        with _: [WalletAsset],
        commandFactory: WalletCommandFactoryProtocol,
        notifying delegate: HistoryFilterEditingDelegate?
    ) {
        guard let view = WalletHistoryFilterViewFactory
            .createView(request: filter, commandFactory: commandFactory, delegate: delegate) else {
            return
        }

        let command = commandFactory.preparePresentationCommand(for: view.controller)
        command.presentationStyle = .modal(inNavigation: true)
        try? command.execute()
    }
}
