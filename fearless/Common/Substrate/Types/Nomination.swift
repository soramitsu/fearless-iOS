import Foundation
import FearlessUtils

struct Nomination: Codable, Equatable {
    let targets: [Data]
    @StringCodable var submittedIn: UInt32
}

extension Nomination {
    var uniqueTargets: [Data] {
        Array(Set(targets))
    }
}
