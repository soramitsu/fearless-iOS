import Foundation
import WalletConnectPairing

extension AppMetadata {
    static func createFearlessMetadata() -> AppMetadata {
        AppMetadata(
            name: "Fearless wallet",
            description: "Defi wallet",
            url: "https://fearlesswallet.io",
            icons: [""],
            redirect: AppMetadata.Redirect(native: "", universal: nil)
        )
    }
}
