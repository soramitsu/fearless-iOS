import UIKit
import SSFModels

protocol ExtrinsicOptionsPresentable: AnyObject {
    func presentOptions(
        with extrinsicHash: String,
        locale: Locale,
        chain: ChainModel,
        from view: ControllerBackedProtocol?
    )
}

extension ExtrinsicOptionsPresentable {
    func presentOptions(
        with extrinsicHash: String,
        locale: Locale,
        chain: ChainModel,
        from view: ControllerBackedProtocol?
    ) {
        let title = R.string.localizable
            .transactionDetailsHashTitle(preferredLanguages: locale.rLanguages)
        let alertController = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .actionSheet
        )

        let copyTitle = R.string.localizable
            .transactionDetailsCopyHash(preferredLanguages: locale.rLanguages)

        let copy = UIAlertAction(title: copyTitle, style: .default) { _ in
            UIPasteboard.general.string = extrinsicHash

            let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
            let controller = ModalAlertFactory.createSuccessAlert(title)

            view?.controller.present(controller, animated: true)
        }

        alertController.addAction(copy)

        chain.externalApi?.explorers?.forEach { explorer in
            guard let url = explorer.explorerUrl(for: extrinsicHash, type: explorer.transactionType) else {
                return
            }
            let title = explorer.type.actionTitle().value(for: locale)
            let action = UIAlertAction(title: title, style: .default) { _ in
                let webController = WebViewFactory.createWebViewController(for: url, style: .automatic)
                view?.controller.present(webController, animated: true, completion: nil)
            }
            alertController.addAction(action)
        }

        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)

        alertController.addAction(cancel)

        view?.controller.present(alertController, animated: true)
    }
}
