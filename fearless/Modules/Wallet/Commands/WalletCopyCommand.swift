import Foundation
import CommonWallet

final class WalletCopyCommand: WalletCommandProtocol {
    weak var commandFactory: WalletCommandFactoryProtocol?
    let copyingString: String
    let alertTitle: String

    init(copyingString: String, alertTitle: String) {
        self.copyingString = copyingString
        self.alertTitle = alertTitle
    }

    func execute() throws {
        UIPasteboard.general.string = copyingString

        let controller = ModalAlertFactory.createSuccessAlert(alertTitle)

        try commandFactory?.preparePresentationCommand(for: controller).execute()
    }
}
