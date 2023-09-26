import Foundation

struct FeatureToggleConfig: Decodable {
    let pendulumCaseEnabled: Bool?

    static var defaultConfig: FeatureToggleConfig {
        FeatureToggleConfig(pendulumCaseEnabled: false)
    }
}
