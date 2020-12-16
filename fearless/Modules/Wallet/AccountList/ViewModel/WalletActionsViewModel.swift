import Foundation
import CommonWallet

protocol WalletDisablingActionProtocol {
    var title: String { get }
    var command: WalletCommandProtocol? { get }
}

protocol WalletActionsViewModelProtocol: ActionsViewModelProtocol {
    var buy: WalletDisablingActionProtocol { get }
}

final class WalletActionViewModel: ActionViewModelProtocol {
    var title: String
    var command: WalletCommandProtocol
    var style: WalletTextStyleProtocol { WalletTextStyle(font: .capsTitle, color: .black) }

    init(title: String, command: WalletCommandProtocol) {
        self.title = title
        self.command = command
    }
}

final class WalletDisablingAction: WalletDisablingActionProtocol {
    let title: String
    let command: WalletCommandProtocol?

    init(title: String, command: WalletCommandProtocol?) {
        self.title = title
        self.command = command
    }
}

final class WalletActionsViewModel: WalletActionsViewModelProtocol {
    var cellReuseIdentifier: String { WalletAccountListConstants.actionsCellId }
    var itemHeight: CGFloat { WalletAccountListConstants.actionsCellHeight }
    var command: WalletCommandProtocol? { nil }

    let send: ActionViewModelProtocol
    let receive: ActionViewModelProtocol
    let buy: WalletDisablingActionProtocol

    init(send: ActionViewModelProtocol,
         receive: ActionViewModelProtocol,
         buy: WalletDisablingActionProtocol) {
        self.send = send
        self.receive = receive
        self.buy = buy
    }
}
