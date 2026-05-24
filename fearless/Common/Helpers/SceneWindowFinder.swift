import UIKit

enum SceneWindowFinder {
    static func activeWindow(from scene: UIWindowScene? = nil) -> UIWindow? {
        let scenes: [UIWindowScene]
        if let scene = scene {
            scenes = [scene]
        } else {
            scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        }

        return scenes
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow && !$0.isHidden }
    }

    static func statusBarHeight(from scene: UIWindowScene? = nil) -> CGFloat {
        scene?.statusBarManager?.statusBarFrame.height
            ?? activeWindow(from: scene)?.windowScene?.statusBarManager?.statusBarFrame.height
            ?? 0
    }

    static func statusPresentableWindow(from scene: UIWindowScene? = nil) -> ApplicationStatusPresentable? {
        activeWindow(from: scene) as? ApplicationStatusPresentable
    }
}
