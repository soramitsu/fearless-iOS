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
        let webViewController = WebViewFactory.createWebViewController(for: action.url,
                                                                       style: .automatic)
        try commandFactory?
                .preparePresentationCommand(for: webViewController)
                .execute()
    }

    func execute() throws {
        if let action = actions.first {
            try handle(action: action)
        }
    }
}
