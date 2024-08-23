import Foundation

struct FeatureToggleConfig: Decodable {
    let pendulumCaseEnabled: Bool?
    let nftEnabled: Bool?

    static var defaultConfig: FeatureToggleConfig {
        FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: true)
    }
}
