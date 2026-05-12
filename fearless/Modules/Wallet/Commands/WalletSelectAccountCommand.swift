import Foundation
import UIKit

final class WalletSelectAccountCommand: WalletCommandProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    init(commandFactory: WalletCommandFactoryProtocol) {
        self.commandFactory = commandFactory
    }

    func execute() throws {
        guard
            let accountManagementView = AccountManagementViewFactory.createViewForSwitch(),
            let command = commandFactory?.preparePresentationCommand(for: accountManagementView.controller)
        else {
            return
        }
        command.presentationStyle = WalletPresentationStyle.push(hidesBottomBar: true)
        try? command.execute()
    }
}
