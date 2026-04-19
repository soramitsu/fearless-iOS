import Foundation
import SSFModels

public extension ChainModel.BlockExplorer {
    init?(type: String, url: URL, apiKey _: String?) {
        self.init(type: type, url: url)
    }
}
