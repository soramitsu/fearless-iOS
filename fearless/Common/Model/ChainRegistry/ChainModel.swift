import Foundation
import SSFModels
import RobinHood

extension ChainModel: Identifiable {
    public var identifier: String { chainId }

    var isSupported: Bool {
        AppVersion.stringValue?.versionLowerThan(iosMinAppVersion) == false
    }

    var stakingSettings: ChainStakingSettings? {
        let oldChainModel = Chain(rawValue: name)
        switch oldChainModel {
        case .soraMain:
            return SoraChainStakingSettings()
        default:
            return DefaultRelaychainChainStakingSettings()
        }
    }
}
