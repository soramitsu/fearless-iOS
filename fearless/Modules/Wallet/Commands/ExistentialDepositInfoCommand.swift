import Foundation
import CommonWallet
import SoraFoundation

struct TransferExistentialState {
    let totalAmount: Decimal
    let availableAmount: Decimal
    let totalAfterTransfer: Decimal
    let existentialDeposit: Decimal
}

final class ExistentialDepositInfoCommand: WalletCommandProtocol {
    let transferState: TransferExistentialState
    let amountFormatter: LocalizableResource<LocalizableDecimalFormatting>

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(
        transferState: TransferExistentialState,
        amountFormatter: LocalizableResource<LocalizableDecimalFormatting>,
        commandFactory: WalletCommandFactoryProtocol
    ) {
        self.transferState = transferState
        self.amountFormatter = amountFormatter
        self.commandFactory = commandFactory
    }

    func execute() throws {
        let viewController = ModalInfoFactory
            .createTransferExistentialState(
                transferState,
                amountFormatter: amountFormatter
            )

        let presentationCommand = commandFactory?.preparePresentationCommand(for: viewController)
        presentationCommand?.presentationStyle = .modal(inNavigation: false)

        try presentationCommand?.execute()
    }
}
