import Foundation

final class AccountConfirmWireframe: AccountConfirmWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func proceed(from view: AccountConfirmViewProtocol?, flow: AccountConfirmFlow?) {
        switch flow {
        case .wallet, .none:
            guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
                return
            }

            rootAnimator.animateTransition(to: pincodeViewController)
        case .chain:
            guard let navigationController = view?.controller.navigationController else {
                return
            }

            MainTransitionHelper.transitToMainTabBarController(
                closing: navigationController,
                animated: true
            )
        }
    }
}
