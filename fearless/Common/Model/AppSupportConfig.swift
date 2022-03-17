import Foundation

struct AppSupportConfig: Codable, Equatable {
    let minSupportedVersion: String?
    let excludedVersions: [String]?
    let foregroundRefreshTimeoutMs: TimeInterval?
}
