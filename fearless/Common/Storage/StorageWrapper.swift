import Foundation
import RobinHood

protocol StorageWrapper: Identifiable, Equatable, Codable {
    var identifier: String { get }
    var data: Data { get }

    init(identifier: String, data: Data)
}
