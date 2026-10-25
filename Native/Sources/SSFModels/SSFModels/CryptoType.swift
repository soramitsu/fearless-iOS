import Foundation

public enum CryptoType: UInt8, Codable, CaseIterable {
    case sr25519
    case ed25519
    case ecdsa

    public var stringValue: String {
        switch self {
        case .sr25519:
            return "sr25519"
        case .ed25519:
            return "ed25519"
        case .ecdsa:
            return "ecdsa"
        }
    }

    public var supportsSeedFromSecretKey: Bool {
        switch self {
        case .ed25519, .ecdsa:
            return true
        case .sr25519:
            return false
        }
    }

    public
    init?(rawValue: String) {
        switch rawValue.lowercased() {
        case "sr25519":
            self = .sr25519
        case "ed25519":
            self = .ed25519
        case "ecdsa", "ethereum":
            self = .ecdsa
        default:
            return nil
        }
    }
}
