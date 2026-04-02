import Foundation
import WalletConnectPairing

extension AppMetadata {
    private static let fearlessMetadata = AppMetadata(
        name: "Fearless wallet",
        description: "Defi wallet",
        url: "https://fearlesswallet.io",
        icons: ["https://raw.githubusercontent.com/soramitsu/shared-features-utils/master/icons/FW%20icon%20128.png"],
        redirect: try! AppMetadata.Redirect(native: "fearless://", universal: nil)
    )

    static func createFearlessMetadata() -> AppMetadata {
        fearlessMetadata
    }
}
