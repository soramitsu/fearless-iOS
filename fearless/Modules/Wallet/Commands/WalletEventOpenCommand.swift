import Foundation
import CommonWallet

final class WalletEventOpenCommand: WalletCommandProtocol {
    let eventId: String
    let locale: Locale
    let chain: Chain

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(
        eventId: String,
        chain: Chain,
        commandFactory: WalletCommandFactoryProtocol,
        locale: Locale
    ) {
        self.eventId = eventId
        self.chain = chain
        self.commandFactory = commandFactory
        self.locale = locale
    }

    func execute() throws {
        // TODO: Localize
        let title = "Event details"
        let alertController = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .actionSheet
        )

        let copyTitle = "Copy Id"

        let copy = UIAlertAction(title: copyTitle, style: .default) { [weak self] _ in
            self?.copyId()
        }

        alertController.addAction(copy)

        if let url = chain.polkascanEventURL(eventId) {
            let polkascanTitle = R.string.localizable
                .transactionDetailsViewPolkascan(preferredLanguages: locale.rLanguages)
            let viewPolkascan = UIAlertAction(title: polkascanTitle, style: .default) { [weak self] _ in
                self?.present(url: url)
            }

            alertController.addAction(viewPolkascan)
        }

        if let url = chain.subscanEventURL(eventId) {
            let subscanTitle = R.string.localizable
                .transactionDetailsViewSubscan(preferredLanguages: locale.rLanguages)
            let viewSubscan = UIAlertAction(title: subscanTitle, style: .default) { [weak self] _ in
                self?.present(url: url)
            }

            alertController.addAction(viewSubscan)
        }

        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)

        alertController.addAction(cancel)

        let command = commandFactory?.preparePresentationCommand(for: alertController)
        command?.presentationStyle = .modal(inNavigation: false)
        try command?.execute()
    }

    private func copyId() {
        UIPasteboard.general.string = eventId

        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        let controller = ModalAlertFactory.createSuccessAlert(title)

        let command = commandFactory?.preparePresentationCommand(for: controller)
        command?.presentationStyle = .modal(inNavigation: false)
        try? command?.execute()
    }

    private func present(url: URL) {
        let webController = WebViewFactory.createWebViewController(for: url, style: .automatic)
        let command = commandFactory?.preparePresentationCommand(for: webController)
        command?.presentationStyle = .modal(inNavigation: false)
        try? command?.execute()
    }
}
