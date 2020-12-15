import Foundation
import CommonWallet

protocol WalletActionsViewModelProtocol: ActionsViewModelProtocol {
    var buy: ActionViewModelProtocol? { get }
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

final class WalletActionsViewModel: WalletActionsViewModelProtocol {
    var cellReuseIdentifier: String { WalletAccountListConstants.actionsCellId }
    var itemHeight: CGFloat { WalletAccountListConstants.actionsCellHeight }
    var command: WalletCommandProtocol? { nil }

    let send: ActionViewModelProtocol
    let receive: ActionViewModelProtocol
    let buy: ActionViewModelProtocol?

    init(send: ActionViewModelProtocol,
         receive: ActionViewModelProtocol,
         buy: ActionViewModelProtocol?) {
        self.send = send
        self.receive = receive
        self.buy = buy
    }
}
