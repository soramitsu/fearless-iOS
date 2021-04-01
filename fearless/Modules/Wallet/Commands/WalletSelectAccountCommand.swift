import Foundation
import CommonWallet

final class WalletSelectAccountCommand: WalletCommandProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    init(commandFactory: WalletCommandFactoryProtocol) {
        self.commandFactory = commandFactory
    }

    func execute() throws {
        guard let accountManagementView = AccountManagementViewFactory.createViewForSwitch() else {
            return
        }

        guard let command = commandFactory?
                .preparePresentationCommand(for: accountManagementView.controller) else {
            return
        }

        command.presentationStyle = .push(hidesBottomBar: true)

        try? command.execute()
    }
}
