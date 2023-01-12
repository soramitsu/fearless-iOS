import Foundation

final class EmailVerificationRouter: EmailVerificationRouterInput {
    func presentPreparation(from _: EmailVerificationViewInput?, data _: SCKYCUserDataModel) {}

    func close(from view: EmailVerificationViewInput?) {
        view?.controller.dismiss(animated: true)
    }
}
