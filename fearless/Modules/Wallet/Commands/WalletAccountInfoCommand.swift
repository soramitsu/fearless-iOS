import Foundation
import CommonWallet
import SoraFoundation

final class WalletAccountInfoCommand: WalletCommandProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let balanceContext: BalanceContext
    let amountFormatter: LocalizableResource<NumberFormatter>

    init(
        balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<NumberFormatter>,
        commandFactory: WalletCommandFactoryProtocol
    ) {
        self.balanceContext = balanceContext
        self.commandFactory = commandFactory
        self.amountFormatter = amountFormatter
    }

    func execute() throws {
        let viewController = ModalInfoFactory.createFromBalanceContext(
            balanceContext,
            amountFormatter: amountFormatter
        )

        let presentationCommand = commandFactory?.preparePresentationCommand(for: viewController)
        presentationCommand?.presentationStyle = .modal(inNavigation: false)

        try presentationCommand?.execute()
    }
}
