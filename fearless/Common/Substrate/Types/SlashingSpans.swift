import Foundation
import SSFUtils

struct SlashingSpans: Decodable {
    @StringCodable var lastNonzeroSlash: UInt32
    let prior: [StringScaleMapper<UInt32>]
}
