import UIKit

/// WalletConnect sheets live in their own window, which is hidden while the PIN screen locks the app. A sheet that
/// disappears because its window was hidden is still open: its request or proposal is answered only when the sheet
/// itself is closed, never because the app locked.
enum WalletConnectSheetVisibility {
    static func isHiddenWithItsWindow(_ controller: UIViewController) -> Bool {
        guard let window = controller.viewIfLoaded?.window else {
            return false
        }
        return window.isHidden
    }
}
