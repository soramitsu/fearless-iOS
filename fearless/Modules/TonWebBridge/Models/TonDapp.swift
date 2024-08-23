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

    static func == (lhs: TonDapp, rhs: TonDapp) -> Bool {
        lhs.url.host == rhs.url.host
    }

    enum CodingKeys: CodingKey {
        case identifier
        case chains
        case name
        case description
        case icon
        case poster
        case url
    }

    init(
        identifier: String,
        chains: [String],
        name: String,
        description: String?,
        icon: URL,
        poster: URL?,
        url: URL
    ) {
        self.identifier = identifier
        self.chains = chains
        self.name = name
        self.description = description
        self.icon = icon
        self.poster = poster
        self.url = url
    }
}
