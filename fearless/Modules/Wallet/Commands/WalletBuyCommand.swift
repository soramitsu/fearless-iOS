import Foundation
import CommonWallet

final class WalletBuyCommand: WalletCommandProtocol {
    let action: PurchaseAction
    weak var commandFactory: WalletCommandFactoryProtocol?

    init(action: PurchaseAction, commandFactory: WalletCommandFactoryProtocol) {
        self.action = action
        self.commandFactory = commandFactory
    }

    func execute() throws {
        guard
            let commandFactory = commandFactory,
            let webView = PurchaseViewFactory.createView(
                for: action,
                commandFactory: commandFactory
            )
        else {
            return
        }

        let command = commandFactory.preparePresentationCommand(for: webView.controller)
        command.presentationStyle = .modal(inNavigation: false)
        try command.execute()
    }
}
