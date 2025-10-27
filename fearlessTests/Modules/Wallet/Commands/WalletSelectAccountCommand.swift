import Foundation
import UIKit
@testable import fearless

final class WalletSelectAccountCommand: WalletCommandProtocol {
    var commandFactory: WalletCommandFactoryProtocol?

    init(commandFactory: WalletCommandFactoryProtocol) {
        self.commandFactory = commandFactory
    }

    func execute() throws {
        // Use a simple controller for tests; real navigation verified via mock
        let vc = UIViewController()
        guard let command = commandFactory?
            .preparePresentationCommand(for: vc)
        else {
            return
        }

        command.presentationStyle = WalletPresentationStyle.push(hidesBottomBar: true)

        try? command.execute()
    }
}
