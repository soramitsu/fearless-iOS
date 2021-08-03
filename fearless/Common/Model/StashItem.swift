import Foundation
import RobinHood

struct StashItem: Codable, Equatable {
    let stash: String
    let controller: String
}

extension StashItem: Identifiable {
    var identifier: String { stash }
}
