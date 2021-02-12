import Foundation
import RobinHood

struct PhishingItem: Codable {
    enum CodingKeys: String, CodingKey {
        case source
        case publicKey
    }

    let source: String
    let publicKey: String
}

extension PhishingItem: Identifiable {
    var identifier: String { publicKey }
}
