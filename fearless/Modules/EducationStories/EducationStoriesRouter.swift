import Foundation

final class EducationStoriesRouter: EducationStoriesRouterProtocol {
    private lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showMain() {
        guard let mainViewController = MainTabBarViewFactory.createView()?.controller else {
            return
        }

        rootAnimator.animateTransition(to: mainViewController)
    }
}
