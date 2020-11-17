import UIKit

extension UIAlertController {
    static func presentAccountOptions(_ address: String,
                                      chain: Chain,
                                      locale: Locale,
                                      copyClosure: @escaping () -> Void,
                                      urlClosure: @escaping  (URL) -> Void) -> UIAlertController {
        let title = R.string.localizable
            .accountInfoTitle(preferredLanguages: locale.rLanguages)
        let alertController = UIAlertController(title: title,
                                                message: nil,
                                                preferredStyle: .actionSheet)

        let copyTitle = R.string.localizable
            .commonCopyAddress(preferredLanguages: locale.rLanguages)

        let copy = UIAlertAction(title: copyTitle, style: .default) { _ in
            copyClosure()
        }

        alertController.addAction(copy)

        if let url = chain.polkascanAddressURL(address) {
            let polkascanTitle = R.string.localizable
                .transactionDetailsViewPolkascan(preferredLanguages: locale.rLanguages)
            let viewPolkascan = UIAlertAction(title: polkascanTitle, style: .default) { _ in
                urlClosure(url)
            }

            alertController.addAction(viewPolkascan)
        }

        if let url = chain.subscanAddressURL(address) {
            let subscanTitle = R.string.localizable
                .transactionDetailsViewSubscan(preferredLanguages: locale.rLanguages)
            let viewSubscan = UIAlertAction(title: subscanTitle, style: .default) { _ in
                urlClosure(url)
            }

            alertController.addAction(viewSubscan)
        }

        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)

        alertController.addAction(cancel)

        return alertController
    }
}
