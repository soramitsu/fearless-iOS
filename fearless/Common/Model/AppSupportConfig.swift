import Foundation

struct AppSupportConfig: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case minSupportedVersion = "min_supported_version"
        case excludedVersions = "exсluded_versions"
    }

    let minSupportedVersion: String?
    let excludedVersions: [String]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        minSupportedVersion = try container.decode(String.self, forKey: .minSupportedVersion)
        excludedVersions = try container.decode([String]?.self, forKey: .excludedVersions)
    }
}
