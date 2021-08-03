import Foundation
import FearlessUtils

struct Nomination: Codable, Equatable {
    let targets: [Data]
    @StringCodable var submittedIn: UInt32
}
