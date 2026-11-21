import UIKit

/// The text side of a pasteboard. Screens that copy or paste take one so tests can hand them a
/// private store: a read of the system pasteboard can wait for a paste-permission answer.
protocol PasteboardStringAccessing: AnyObject {
    var string: String? { get set }
}

extension UIPasteboard: PasteboardStringAccessing {}

protocol TextCopyPresentable {
    func presentCopy(
        with text: String,
        locale: Locale,
        from view: ControllerBackedProtocol?
    )
}

extension TextCopyPresentable {
    func presentCopy(
        with text: String,
        locale: Locale,
        from view: ControllerBackedProtocol?
    ) {
        let alertController = UIAlertController(
            title: text,
            message: nil,
            preferredStyle: .actionSheet
        )

        let copyTitle = R.string.localizable
            .commonCopyId(preferredLanguages: locale.rLanguages)

        let copy = UIAlertAction(title: copyTitle, style: .default) { _ in
            UIPasteboard.general.string = text

            let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
            let controller = ModalAlertFactory.createSuccessAlert(title)

            view?.controller.present(controller, animated: true)
        }

        let cancel = UIAlertAction(title: R.string.localizable.commonCancel(preferredLanguages: locale.rLanguages), style: .cancel)

        alertController.addAction(copy)
        alertController.addAction(cancel)

        view?.controller.anchorPopover(of: alertController)
        view?.controller.present(alertController, animated: true)
    }
}
