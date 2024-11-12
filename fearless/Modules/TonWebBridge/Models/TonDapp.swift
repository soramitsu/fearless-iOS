import Foundation
import RobinHood

struct TonDapp: Codable, Equatable, Identifiable {
    let identifier: String
    let chains: [String]
    let name: String
    let description: String?
    let icon: URL
    let poster: URL?
    let url: URL

    enum CodingKeys: CodingKey {
        case identifier
        case chains
        case name
        case description
        case icon
        case poster
        case url
    }
}
