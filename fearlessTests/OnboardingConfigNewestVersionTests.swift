import XCTest
import SoraKeystore
@testable import fearless

/// With no config for the exact app version, the resolver meant to take the newest config made for an older version,
/// but sorted the versions ascending and took the first: an install of 4.2.3 got the 3.6.1 onboarding instead of
/// 4.0.4's, and someone who had seen 3.7.x was never shown 4.0.4's.
final class OnboardingConfigNewestVersionTests: XCTestCase {
    func testTheNewestConfigOlderThanTheAppIsChosen() throws {
        let resolver = OnboardingConfigVersionResolver(userDefaultsStorage: InMemorySettingsManager())
        let configs = try ["0.0.1", "0.1.0", "0.0.5"].map { try CovJOnOnboardingFixture.config(minVersion: $0) }

        XCTAssertEqual(resolver.resolve(configWrappers: configs)?.minVersion, "0.1.0")
    }

    func testANewerConfigThanTheOneLastShownIsShown() throws {
        let storage = InMemorySettingsManager()
        storage.set(value: "0.0.5", for: OnboardingKeys.lastShownOnboardingVersion.rawValue)
        let resolver = OnboardingConfigVersionResolver(userDefaultsStorage: storage)
        let configs = try ["0.0.1", "0.1.0"].map { try CovJOnOnboardingFixture.config(minVersion: $0) }

        XCTAssertEqual(resolver.resolve(configWrappers: configs)?.minVersion, "0.1.0")

        storage.set(value: "0.1.0", for: OnboardingKeys.lastShownOnboardingVersion.rawValue)
        XCTAssertNil(resolver.resolve(configWrappers: configs), "a config already shown is not shown again")
    }
}
