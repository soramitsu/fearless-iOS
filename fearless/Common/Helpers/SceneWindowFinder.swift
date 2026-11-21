import UIKit

enum SceneWindowFinder {
    static func activeWindow(from scene: UIWindowScene? = nil) -> UIWindow? {
        if #available(iOS 13.0, *) {
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
        } else {
            return UIApplication.shared.windows.first { $0.isKeyWindow && !$0.isHidden }
        }
    }

    /// The app's own window: the visible window at the normal level, preferring `FearlessWindow`. Prompts in windows
    /// above it (WalletConnect and IrohaConnect requests, the app-switcher cover) may be key, but the lock screen
    /// never goes there: hiding such a window would hide the PIN with it.
    static func mainWindow(from scene: UIWindowScene? = nil) -> UIWindow? {
        let scenes: [UIWindowScene]
        if let scene = scene {
            scenes = [scene]
        } else {
            scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        }
        let windows = scenes.flatMap { $0.windows }.filter {
            !$0.isHidden && $0.windowLevel == .normal && $0.rootViewController != nil
        }
        return windows.first { $0 is FearlessWindow } ?? windows.first
    }

    static func statusBarHeight(from scene: UIWindowScene? = nil) -> CGFloat {
        if #available(iOS 13.0, *) {
            return scene?.statusBarManager?.statusBarFrame.height
                ?? activeWindow(from: scene)?.windowScene?.statusBarManager?.statusBarFrame.height
                ?? 0
        } else {
            return activeWindow(from: scene)?.safeAreaInsets.top ?? 20
        }
    }

    static func statusPresentableWindow(from scene: UIWindowScene? = nil) -> ApplicationStatusPresentable? {
        activeWindow(from: scene) as? ApplicationStatusPresentable
    }
}
