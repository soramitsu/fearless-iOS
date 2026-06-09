import Foundation
import UIKit
import FearlessFoundation
import FearlessSecureStorage

// Wallet command protocols/types — single source for the app target.
protocol WalletCommandProtocol {
    func execute() throws
}

protocol WalletCommandDecoratorProtocol: WalletCommandProtocol {
    var undelyingCommand: WalletCommandProtocol? { get set }
}

enum WalletDismissAction {
    case dismiss
    case pop
}

enum WalletPresentationStyle {
    case modal(inNavigation: Bool)
    case push(hidesBottomBar: Bool)
}

final class WalletPresentationCommand: WalletCommandProtocol {
    var presentationStyle: WalletPresentationStyle = .modal(inNavigation: false)
    var completionBlock: (() throws -> Void)?
    private weak var presentingController: UIViewController?

    init(presentingController: UIViewController? = nil) {
        self.presentingController = presentingController
    }

    func execute() throws {
        try completionBlock?()
    }
}

protocol WalletCommandFactoryProtocol: AnyObject {
    func preparePresentationCommand(for controller: UIViewController) -> WalletPresentationCommand
    func prepareHideCommand(with action: WalletDismissAction) -> WalletPresentationCommand
}

protocol WalletSelectAccountCommandFactoryProtocol {
    func createCommand(_ walletCommandFactory: WalletCommandFactoryProtocol) -> WalletSelectAccountCommand
}

final class WalletSelectAccountCommandFactory: WalletSelectAccountCommandFactoryProtocol {
    func createCommand(_ walletCommandFactory: WalletCommandFactoryProtocol) -> WalletSelectAccountCommand {
        WalletSelectAccountCommand(commandFactory: walletCommandFactory)
    }
}
