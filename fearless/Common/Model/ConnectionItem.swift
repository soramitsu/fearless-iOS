import Foundation

struct ConnectionItem: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case title
        case url
        case type
    }

    let title: String
    let url: URL
    let type: UInt8
}
