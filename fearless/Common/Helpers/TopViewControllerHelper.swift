import UIKit

final class TopViewControllerHelper {
    static func getTopViewController(from scene: UIWindowScene? = nil) -> UIViewController? {
        guard var topController = SceneWindowFinder.activeWindow(from: scene)?.rootViewController else {
            return nil
        }

        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }

        return topController
    }
}
