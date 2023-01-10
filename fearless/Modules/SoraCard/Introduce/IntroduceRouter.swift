import Foundation

final class IntroduceRouter: IntroduceRouterInput {
    func presentVerificationEmail(
        from _: IntroduceViewInput?,
        phone _: String,
        name _: String,
        lastName _: String
    ) {}

    func close(from view: IntroduceViewInput?) {
        view?.controller.dismiss(animated: true)
    }
}
