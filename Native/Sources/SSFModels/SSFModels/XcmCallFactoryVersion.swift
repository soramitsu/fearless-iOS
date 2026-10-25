import Foundation

/// XCM version of the calls to build. Live runtimes accept V3, V4 and V5; nothing accepts V1 or V2
/// any more, so the call factory refuses `V1`.
public enum XcmCallFactoryVersion: String, Codable {
    case V1 = "v1"
    case V3 = "v3"
    case V4 = "v4"
    case V5 = "v5"
}
