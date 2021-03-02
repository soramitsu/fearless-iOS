import UIKit
import Foundation

protocol AddressOptionsPresentable {
    func presentAccountOptions(from view: ControllerBackedProtocol,
                               address: String,
                               chain: Chain,
                               locale: Locale)
}

extension AddressOptionsPresentable {
    private func copyAddress(from view: ControllerBackedProtocol,
                             address: String,
                             locale: Locale) {
        UIPasteboard.general.string = address

        let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
        let controller = ModalAlertFactory.createSuccessAlert(title)

        view.controller.present(controller,
                                animated: true,
                                completion: nil)
    }

    private func present(from view: ControllerBackedProtocol,
                         url: URL) {
        let webController = WebViewFactory.createWebViewController(for: url, style: .automatic)
        view.controller.present(webController,
                                animated: true,
                                completion: nil)
    }

    func presentAccountOptions(from view: ControllerBackedProtocol,
                               address: String,
                               chain: Chain,
                               locale: Locale) {
        let copyClosure = { copyAddress(from: view, address: address, locale: locale) }

        let urlClosure = { (url: URL) in
            present(from: view, url: url)
        }

        let controller = UIAlertController.presentAccountOptions(address,
                                                                 chain: chain,
                                                                 locale: locale,
                                                                 copyClosure: copyClosure,
                                                                 urlClosure: urlClosure)

        view.controller.present(controller, animated: true, completion: nil)
    }
}
