import Foundation

public enum VaultState: Sendable, Hashable {
    /// No app password yet (first launch).
    case uninitialized
    case locked
    case unlocked
}

/// How the user proves presence when unlocking or signing.
public enum UserApproval: Sendable, Hashable {
    case password(String)
    /// Touch ID (or the Mac login password as the system fallback).
    case biometrics(reason: String)
}

public enum BiometricsAvailability: Sendable, Hashable {
    /// No Touch ID on this Mac, or the app build cannot use protected keychain items.
    case unavailable(reason: String)
    case available
    case enabled
}

public enum PasswordStrength: Int, Sendable, Comparable, CaseIterable {
    case tooShort
    case weak
    case fair
    case strong

    public static func < (lhs: PasswordStrength, rhs: PasswordStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var displayName: String {
        switch self {
        case .tooShort: return "Too short"
        case .weak: return "Weak"
        case .fair: return "Fair"
        case .strong: return "Strong"
        }
    }
}

/// App password rules shared by the UI (live meter) and the engine (enforcement).
public enum PasswordPolicy {
    public static let minimumLength = 8

    private static let common: Set<String> = [
        "password", "password1", "password123", "12345678", "123456789", "1234567890",
        "qwertyui", "qwerty123", "11111111", "00000000", "iloveyou", "letmein1",
        "fearless", "polkadot", "abcdefgh", "abc12345", "passw0rd", "changeme"
    ]

    public static func evaluate(_ password: String) -> PasswordStrength {
        guard password.count >= minimumLength else { return .tooShort }
        if common.contains(password.lowercased()) || Set(password).count <= 2 {
            return .weak
        }
        var classes = 0
        if password.contains(where: \.isLowercase) { classes += 1 }
        if password.contains(where: \.isUppercase) { classes += 1 }
        if password.contains(where: \.isNumber) { classes += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber }) { classes += 1 }
        var score = classes
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }
        switch score {
        case ...2: return .weak
        case 3: return .fair
        default: return .strong
        }
    }

    /// The engine refuses anything below `.fair`.
    public static func isAcceptable(_ password: String) -> Bool {
        evaluate(password) >= .fair
    }
}
