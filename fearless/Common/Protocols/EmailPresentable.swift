import Foundation
import MessageUI

typealias EmailComposerCompletion = (Bool) -> Void

protocol EmailPresentable {
    @discardableResult
    func writeEmail(with message: SocialMessage,
                    from view: ControllerBackedProtocol,
                    completionHandler: EmailComposerCompletion?) -> Bool
}

extension EmailPresentable {
    @discardableResult
    func writeEmail(with message: SocialMessage,
                    from view: ControllerBackedProtocol,
                    completionHandler: EmailComposerCompletion?) -> Bool {
        return MFEmailPresenter.shared.presentComposer(with: message,
                                                       from: view,
                                                       completionBlock: completionHandler)
    }
}

private class MFEmailPresenter: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = MFEmailPresenter()

    private(set) var completionBlock: EmailComposerCompletion?
    private(set) var message: SocialMessage?

    private override init() {}

    func presentComposer(with message: SocialMessage,
                         from view: ControllerBackedProtocol,
                         completionBlock: EmailComposerCompletion?) -> Bool {
        guard self.message == nil else {
            return false
        }

        guard MFMailComposeViewController.canSendMail() else {
            return false
        }

        self.message = message
        self.completionBlock = completionBlock

        let emailComposer = MFMailComposeViewController()

        if let subject = message.subject {
            emailComposer.setSubject(subject)
        }

        if let body = message.body {
            emailComposer.setMessageBody(body, isHTML: false)
        }

        if message.recepients.count > 0 {
            emailComposer.setToRecipients(message.recepients)
        }

        emailComposer.mailComposeDelegate = self

        view.controller.present(emailComposer,
                                animated: true,
                                completion: nil)

        return true
    }

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {

        controller.presentingViewController?.dismiss(animated: true) {
            let completionBlock = self.completionBlock

            self.clearContext()

            switch result {
            case .cancelled, .failed:
                completionBlock?(false)
            case .saved, .sent:
                completionBlock?(true)
            @unknown default:
                completionBlock?(false)
            }
        }
    }

    private func clearContext() {
        message = nil
        completionBlock = nil
    }
}
