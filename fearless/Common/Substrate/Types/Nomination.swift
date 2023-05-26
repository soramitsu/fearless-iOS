import Foundation
import SSFUtils

struct Nomination: Codable, Equatable {
    let targets: [Data]
    @StringCodable var submittedIn: UInt32
}

extension Nomination {
    var uniqueTargets: [Data] {
        Array(Set(targets))
    }
}
