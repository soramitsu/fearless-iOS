import Foundation
import CommonWallet

final class WalletExtrinsicOpenCommand: WalletCommandProtocol {
    let extrinsicHash: String
    let locale: Locale
    let chain: Chain

    weak var commandFactory: WalletCommandFactoryProtocol?

    init(extrinsicHash: String,
         chain: Chain,
         commandFactory: WalletCommandFactoryProtocol,
         locale: Locale) {
        self.extrinsicHash = extrinsicHash
        self.chain = chain
        self.commandFactory = commandFactory
        self.locale = locale
    }

    func execute() throws {
        let title = R.string.localizable
            .transactionDetailsHashTitle(preferredLanguages: locale.rLanguages)
        let alertController = UIAlertController(title: title,
                                                message: nil,
                                                preferredStyle: .actionSheet)

        let copyTitle = R.string.localizable
            .transactionDetailsCopyHash(preferredLanguages: locale.rLanguages)

        let copy = UIAlertAction(title: copyTitle, style: .default) { [weak self] _ in
            self?.copyHash()
        }

        alertController.addAction(copy)

        if let url = chain.polkascanExtrinsicURL(extrinsicHash) {
            let polkascanTitle = R.string.localizable
                .transactionDetailsViewPolkascan(preferredLanguages: locale.rLanguages)
            let viewPolkascan = UIAlertAction(title: polkascanTitle, style: .default) { [weak self] _ in
                self?.present(url: url)
            }

            alertController.addAction(viewPolkascan)
        }

        if let url = chain.subscanExtrinsicURL(extrinsicHash) {
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

    private func copyHash() {
        UIPasteboard.general.string = extrinsicHash
    }

    private func present(url: URL) {
        let webController = WebViewFactory.createWebViewController(for: url, style: .automatic)
        let command = commandFactory?.preparePresentationCommand(for: webController)
        command?.presentationStyle = .modal(inNavigation: false)
        try? command?.execute()
    }
}
