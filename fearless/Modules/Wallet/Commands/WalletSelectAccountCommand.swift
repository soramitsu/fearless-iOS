import Foundation

final class WalletSelectAccountCommand: WalletCommandProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    init(commandFactory: WalletCommandFactoryProtocol) {
        self.commandFactory = commandFactory
    }

    func execute() throws {
        // Minimal fallback: present an empty controller when AccountManagementViewFactory is unavailable
        let placeholderController = UIViewController()
        guard let command = commandFactory?.preparePresentationCommand(for: placeholderController) else {
            return
        }
        command.presentationStyle = .push(hidesBottomBar: true)
        try? command.execute()
    }
}
