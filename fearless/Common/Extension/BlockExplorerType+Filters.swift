import Foundation
import SSFModels

extension BlockExplorerType {
    var hasFilters: Bool {
        switch self {
        case .giantsquid:
            return true
        default:
            return false
        }
    }
}
