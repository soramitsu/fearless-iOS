import Foundation
import CommonWallet

final class WalletBuyCommand: WalletCommandProtocol {
    let actions: [PurchaseAction]
    weak var commandFactory: WalletCommandFactoryProtocol?

    init(actions: [PurchaseAction], commandFactory: WalletCommandFactoryProtocol) {
        self.actions = actions
        self.commandFactory = commandFactory
    }

    private func handle(action: PurchaseAction) throws {
        guard
            let commandFactory = commandFactory,
            let webView = PurchaseViewFactory.createView(for: action,
                                                         commandFactory: commandFactory) else {
            return
        }

        let command = commandFactory.preparePresentationCommand(for: webView.controller)
        command.presentationStyle = .modal(inNavigation: false)
        try command.execute()
    }

    func execute() throws {
        if let action = actions.first {
            try handle(action: action)
        }
    }
}
