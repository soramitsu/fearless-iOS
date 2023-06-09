import Foundation
import RobinHood
import SSFModels

extension ChainNodeModel: Identifiable {
    public var identifier: String { url.absoluteString }
}
