import Foundation
import FearlessUtils

typealias EraIndex = UInt32

struct ActiveEraInfo: Codable, Equatable {
    @StringCodable var index: EraIndex
}
