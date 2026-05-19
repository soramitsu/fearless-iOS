import Foundation
import RobinHood
import SSFModels

extension ChainNodeModel: @retroactive Identifiable {
    public var identifier: String { url.absoluteString }
}
