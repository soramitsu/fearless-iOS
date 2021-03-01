import Foundation
import FearlessUtils

struct SlashingSpans: Decodable {
    @StringCodable var lastNonzeroSlash: UInt32
}
