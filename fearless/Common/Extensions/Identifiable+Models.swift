import Foundation
import SSFModels
import RobinHood

// Ensure models from SSF conform to RobinHood.Identifiable for repository/generic APIs.
extension AssetModel: RobinHood.Identifiable {
    public var identifier: String { id }
}
