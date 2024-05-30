import UIKit
import SSFModels

extension UIAlertController {
    static func presentAccountOptions(
        _ address: String,
        chain: ChainModel,
        locale: Locale,
        copyClosure: @escaping () -> Void,
        urlClosure: @escaping (URL) -> Void,
        exportClosure: (() -> Void)? = nil
    ) -> UIAlertController {
        var title = address

        let offset = title.count / 2
        title.insert(
            contentsOf: String.returnKey,
            at: title.index(title.startIndex, offsetBy: offset)
        )

        let alertController = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .actionSheet
        )

        let copyTitle = R.string.localizable
            .commonCopyAddress(preferredLanguages: locale.rLanguages)

        let copy = UIAlertAction(title: copyTitle, style: .default) { _ in
            copyClosure()
        }

        alertController.addAction(copy)

        chain.externalApi?.explorers?.forEach { explorer in
            guard let url = explorer.explorerUrl(for: address, type: .address) else {
                return
            }
            let title = explorer.type.actionTitle().value(for: locale)
            let action = UIAlertAction(title: title, style: .default) { _ in
                urlClosure(url)
            }
            alertController.addAction(action)
        }

        if let exportClosure = exportClosure {
            let exportTitle = R.string.localizable.commonExport(preferredLanguages: locale.rLanguages)
            let showExportFlow = UIAlertAction(title: exportTitle, style: .default) { _ in
                exportClosure()
            }
            alertController.addAction(showExportFlow)
        }

        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale.rLanguages)
        let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)

        alertController.addAction(cancel)

        return alertController
    }
}
