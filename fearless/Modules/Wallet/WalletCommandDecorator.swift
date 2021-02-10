import Foundation
import CommonWallet
import SoraFoundation

final class StubCommandDecorator: WalletCommandDecoratorProtocol {
    var undelyingCommand: WalletCommandProtocol?

    func execute() throws {}
}

final class WalletCommandDecoratorFactory: WalletCommandDecoratorFactoryProtocol {
    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func createTransferConfirmationDecorator(with commandFactory: WalletCommandFactoryProtocol,
                                             payload: ConfirmationPayload)
    -> WalletCommandDecoratorProtocol? {
        let transferConfirmCommand = TransferConfirmCommand(payload: payload,
                                                            localizationManager: localizationManager,
                                                            commandFactory: commandFactory)
        return TransferConfirmCommandProxy(transferConfirmCommand: transferConfirmCommand)
    }
}
