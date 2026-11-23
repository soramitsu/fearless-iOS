import SwiftUI
import WalletCore
import WalletEngine
import WalletUI

/// Composition root: the live wallet engine behind the SwiftUI interface.
@main
struct FearlessMacApp: App {
    private let services: WalletServices

    init() {
        services = WalletEngineFactory.makeLiveServices(configuration: AppEnvironment.engineConfiguration())
    }

    var body: some Scene {
        FearlessScenes(services: services)
    }
}
