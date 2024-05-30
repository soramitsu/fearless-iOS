import Foundation
import SoraFoundation

public struct WalletAssetModes: OptionSet {
    public static let view = WalletAssetModes(rawValue: 1 << 0)
    public static let transfer = WalletAssetModes(rawValue: 1 << 1)
    public static let all: WalletAssetModes = [.view, .transfer]

    public typealias RawValue = UInt8

    public let rawValue: UInt8

    public init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

public struct WalletAsset {
    public let symbol: String
    public let name: LocalizableResource<String>
    public let identifier: String
    public let precision: Int16
    public let platform: LocalizableResource<String>?
    public let modes: WalletAssetModes

    public init(
        identifier: String,
        name: LocalizableResource<String>,
        platform: LocalizableResource<String>? = nil,
        symbol: String,
        precision: Int16,
        modes: WalletAssetModes = .all
    ) {
        self.identifier = identifier
        self.name = name
        self.symbol = symbol
        self.precision = precision
        self.platform = platform
        self.modes = modes
    }
}

extension WalletAsset: Hashable {
    public static func == (lhs: WalletAsset, rhs: WalletAsset) -> Bool {
        lhs.identifier == rhs.identifier
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}
