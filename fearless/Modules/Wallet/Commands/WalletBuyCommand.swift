import Foundation
import CommonWallet

final class WalletBuyCommand: WalletCommandProtocol {
    let actions: [PurchaseAction]
    weak var commandFactory: WalletCommandFactoryProtocol?
    var selectedIndex: Int?

    init(actions: [PurchaseAction], commandFactory: WalletCommandFactoryProtocol) {
        self.actions = actions
        self.commandFactory = commandFactory
    }

    private func handle(action: PurchaseAction) throws {
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

    private func showBuyOptions(
        items: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) throws {
        guard
            let commandFactory = commandFactory,
            let manageView = ModalPickerFactory.createPickerForList(
                items,
                delegate: delegate,
                context: context
            )
        else {
            return
        }

        let command = commandFactory.preparePresentationCommand(for: manageView)
        command.presentationStyle = .modal(inNavigation: false)
        try command.execute()
    }

    func execute() throws {
        guard !actions.isEmpty else { return }

        if actions.count > 1 {
            try showBuyOptions(items: actions, delegate: self, context: nil)
        } else {
            try handle(action: actions.first!)
        }
    }
}

extension WalletBuyCommand: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        let command = commandFactory?.prepareHideCommand(with: .dismiss)
//        command.completionBlock = { try? self.handle(action: actions[index]) }
        try? command?.execute()
    }
}
