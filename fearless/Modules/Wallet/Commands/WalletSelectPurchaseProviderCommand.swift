import Foundation
import CommonWallet

final class WalletSelectPurchaseProviderCommand: WalletCommandProtocol {
    let actions: [PurchaseAction]
    weak var commandFactory: WalletCommandFactoryProtocol?

    init(actions: [PurchaseAction], commandFactory: WalletCommandFactoryProtocol) {
        self.actions = actions
        self.commandFactory = commandFactory
    }

    private func handle(selectedIndex index: Int) throws {
        guard let commandFactory = commandFactory else { return }
        let command = WalletBuyCommand(action: actions[index], commandFactory: commandFactory)
        try command.execute()
    }

    private func presentBuyOptions(
        items: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) throws {
        guard
            let commandFactory = commandFactory,
            let pickerView = ModalPickerFactory.createPickerForList(
                items,
                delegate: delegate,
                context: context
            )
        else { return }

        let command = commandFactory.preparePresentationCommand(for: pickerView)
        command.presentationStyle = .modal(inNavigation: false)
        try command.execute()
    }

    func execute() throws {
        guard !actions.isEmpty else { return }

        if actions.count > 1 {
            try presentBuyOptions(items: actions, delegate: self, context: nil)
        } else {
            try handle(selectedIndex: 0)
        }
    }
}

extension WalletSelectPurchaseProviderCommand: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        let command = commandFactory?.prepareHideCommand(with: .dismiss)
        command?.completionBlock = { try? self.handle(selectedIndex: index) }
        try? command?.execute()
    }
}
