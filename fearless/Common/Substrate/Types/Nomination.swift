import Foundation
import SSFUtils

struct Nomination: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case targets
        case submittedIn
    }

    let targets: [Data]
    @StringCodable var submittedIn: UInt32

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            targets = try container.decode([Data].self, forKey: .targets)
        } catch {
            let targetsHex = try container.decode([String].self, forKey: .targets)
            targets = targetsHex.compactMap { Data(hex: $0) }
        }

        submittedIn = try container.decode(StringScaleMapper<UInt32>.self, forKey: .submittedIn).value
    }
}

extension Nomination {
    var uniqueTargets: [Data] {
        Array(Set(targets))
    }
}
