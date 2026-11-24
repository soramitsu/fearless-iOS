import Foundation

class CheckPincodeWireframe: PinSetupWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    private let lockState: ApplicationLockState

    init(lockState: ApplicationLockState = .shared) {
        self.lockState = lockState
    }

    func showMain(from view: PinSetupViewProtocol?) {
        // Without its own screen there is no lock this PIN may end.
        guard let controller = view?.controller else {
            return
        }

        controller.dismiss(animated: true) { [lockState, controller] in
            // Only the lock this PIN screen holds: a newer lock shown meanwhile stays.
            lockState.unlock(from: controller)
        }
    }

    func showSignup(from _: PinSetupViewProtocol?) {
        guard let signupViewController = OnboardingMainViewFactory.createViewForOnboarding()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: signupViewController)
    }
}
