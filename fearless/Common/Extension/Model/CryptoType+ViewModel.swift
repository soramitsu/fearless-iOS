import Foundation

extension CryptoType {
    func titleForLocale(_ locale: Locale) -> String {
        switch self {
        case .sr25519:
            return "Schnorrkel"
        case .ed25519:
            return "Edwards"
        case .ecdsa:
            return "ECDSA"
        }
    }

    func subtitleForLocale(_ locale: Locale) -> String {
        switch self {
        case .sr25519:
            return "sr25519 (recommended)"
        case .ed25519:
            return "ed25519 (alternative)"
        case .ecdsa:
            return "(BTC/ETH compatible)"
        }
    }
}
