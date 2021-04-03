import Foundation
import CommonWallet
import SoraFoundation
import SoraKeystore

protocol WalletSelectAccountCommandFactoryProtocol {
    func createCommand(_ walletCommandFactory: WalletCommandFactoryProtocol) -> WalletSelectAccountCommand
}

final class WalletSelectAccountCommandFactory: WalletSelectAccountCommandFactoryProtocol {
    func createCommand(_ walletCommandFactory: WalletCommandFactoryProtocol) -> WalletSelectAccountCommand {
        WalletSelectAccountCommand(commandFactory: walletCommandFactory)
    }
}
