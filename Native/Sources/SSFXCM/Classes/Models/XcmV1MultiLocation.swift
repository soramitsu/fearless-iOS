import Foundation
import SSFUtils

struct XcmV1MultiLocation: Codable {
    @StringCodable var parents: UInt8
    let interior: XcmV1MultilocationJunctions
}

extension XcmV1MultiLocation: Equatable {}
