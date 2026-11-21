import Foundation

class CheckPincodeWireframe: PinSetupWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    private let lockState: ApplicationLockState

    init(lockState: ApplicationLockState = .shared) {
        self.lockState = lockState
    }

    func showMain(from view: PinSetupViewProtocol?) {
        guard let controller = view?.controller else {
            lockState.unlock()
            return
        }

        controller.dismiss(animated: true) { [lockState] in
            lockState.unlock()
        }
    }

    func showSignup(from _: PinSetupViewProtocol?) {
        guard let signupViewController = OnboardingMainViewFactory.createViewForOnboarding()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: signupViewController)
    }
}
