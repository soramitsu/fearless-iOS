import Foundation
import FearlessWalletConnect

extension AppMetadata {
    private static let fearlessMetadata = AppMetadata(
        name: "Fearless wallet",
        description: "Defi wallet",
        url: "https://fearlesswallet.io",
        icons: ["https://raw.githubusercontent.com/soramitsu/fearless-iOS/master/remote-config/production/icons/FW%20icon%20128.png"],
        redirect: AppMetadata.Redirect(native: "fearless://", universal: nil)
    )

    static func createFearlessMetadata() -> AppMetadata {
        fearlessMetadata
    }
}
