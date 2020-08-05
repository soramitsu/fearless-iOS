import Foundation

struct ConnectionItem: Codable, Equatable {
    let title: String
    let url: URL
    let type: UInt8
}
