import Foundation
import UIKit

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
        // No-op placeholder to satisfy invocations in tests/builds.
        // Real presentation actions are handled by concrete wireframes elsewhere.
        try completionBlock?()
    }
}

protocol WalletCommandFactoryProtocol: AnyObject {
    func preparePresentationCommand(for controller: UIViewController) -> WalletPresentationCommand
    func prepareHideCommand(with action: WalletDismissAction) -> WalletPresentationCommand
}
