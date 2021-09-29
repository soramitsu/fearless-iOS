import Foundation
import CommonWallet
import SoraFoundation

final class WalletAccountInfoCommand: WalletCommandProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?

    let balanceContext: BalanceContext
    let amountFormatter: LocalizableResource<LocalizableDecimalFormatting>
    let priceFormatter: LocalizableResource<TokenFormatter>

    init(
        balanceContext: BalanceContext,
        amountFormatter: LocalizableResource<LocalizableDecimalFormatting>,
        priceFormatter: LocalizableResource<TokenFormatter>,
        commandFactory: WalletCommandFactoryProtocol
    ) {
        self.balanceContext = balanceContext
        self.amountFormatter = amountFormatter
        self.priceFormatter = priceFormatter
        self.commandFactory = commandFactory
    }

    func execute() throws {
        let viewController = ModalInfoFactory.createFromBalanceContext(
            balanceContext,
            amountFormatter: amountFormatter,
            priceFormatter: priceFormatter
        )

        let presentationCommand = commandFactory?.preparePresentationCommand(for: viewController)
        presentationCommand?.presentationStyle = .modal(inNavigation: false)

        try presentationCommand?.execute()
    }
}
