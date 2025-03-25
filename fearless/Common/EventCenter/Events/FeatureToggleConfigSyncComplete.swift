import Foundation
import SSFModels

struct FeatureToggleConfigSyncComplete: EventProtocol {
    let config: FeatureToggleConfig

    func accept(visitor: EventVisitorProtocol) {
        visitor.processFeatureToggleConfigSyncComplete(event: self)
    }
}
