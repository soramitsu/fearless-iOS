import Foundation
import SSFUtils

public struct SlashingSpans: Decodable {
    @StringCodable var lastNonzeroSlash: UInt32
    public let prior: [StringCodable<UInt32>]
}
