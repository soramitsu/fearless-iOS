import Foundation
import RobinHood

struct ChainSettings: Equatable, Codable, Hashable {
    let chainId: String
    let autobalanced: Bool
    var issueMuted: Bool

    mutating func setIssueMuted(_ muted: Bool) {
        issueMuted = muted
    }

    static func defaultSettings(for chainId: String) -> ChainSettings {
        ChainSettings(
            chainId: chainId,
            autobalanced: true,
            issueMuted: false
        )
    }
}

extension ChainSettings: Identifiable {
    var identifier: String { chainId }
}
