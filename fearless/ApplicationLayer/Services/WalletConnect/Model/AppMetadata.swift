import Foundation
import WalletConnectPairing

extension AppMetadata {
    static func createFearlessMetadata() -> AppMetadata {
        AppMetadata(
            name: "Fearless wallet",
            description: "Defi wallet",
            url: "https://fearlesswallet.io",
            icons: ["https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/icons/FW%20icon%20128.png"],
            redirect: AppMetadata.Redirect(native: "", universal: nil)
        )
    }
}
