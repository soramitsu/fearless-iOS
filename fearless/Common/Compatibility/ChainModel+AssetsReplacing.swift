import Foundation
import SSFModels

// Compatibility shim: older code used `chain.replacing(_ assets: [AssetModel])`.
// New SSFModels no longer provides this helper, so recreate minimal behavior.
extension ChainModel {
    @discardableResult
    func replacing(_ assets: [AssetModel]) -> ChainModel {
        self.assets = Set(assets)
        return self
    }
}
