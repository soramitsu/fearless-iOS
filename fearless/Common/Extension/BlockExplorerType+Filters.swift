import Foundation
import SSFModels

extension BlockExplorerType {
    var hasFilters: Bool {
        switch self {
        case .fire, .blockscout, .klaytn, .oklink, .zchain, .vicscan:
            return false
        default:
            return true
        }
    }
}
