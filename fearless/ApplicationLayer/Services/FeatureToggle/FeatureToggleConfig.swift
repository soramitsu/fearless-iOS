import Foundation

struct FeatureToggleConfig: Decodable {
    let pendulumCaseEnabled: Bool?
    let nftEnabled: Bool?
    let dappEnabled: Bool?

    static var defaultConfig: FeatureToggleConfig {
        FeatureToggleConfig(pendulumCaseEnabled: false, nftEnabled: true, dappEnabled: true)
    }
}
