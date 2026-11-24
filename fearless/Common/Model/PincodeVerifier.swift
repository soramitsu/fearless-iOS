import CommonCrypto
import Foundation
import Security
import SoraKeystore

/// The app PIN stored as a salted, slow verifier instead of its digits (design doc 3.7):
/// `fearless-pin-v1$<iterations>$<salt, base64>$<PBKDF2-HMAC-SHA256, base64>`.
///
/// A stored value without the prefix is a PIN an earlier release saved as plain UTF-8; it is
/// compared as before and replaced by a verifier after it matches. A six-digit PIN cannot resist
/// an offline search of its verifier; the point is that a keychain dump no longer contains the PIN
/// itself, which people reuse elsewhere. Wallet keys never depend on it.
enum PincodeVerifier {
    static let prefix = "fearless-pin-v1$"
    static let iterations: UInt32 = 310_000
    static let saltLength = 16
    static let outputLength = 32

    static func isVerifier(_ stored: String) -> Bool {
        stored.hasPrefix(prefix)
    }

    /// A new verifier for `pin` with a fresh random salt.
    static func make(pin: String, iterations: UInt32 = iterations) throws -> String {
        guard !pin.isEmpty else {
            throw PincodeVerifierError.derivationFailed
        }
        var salt = Data(count: saltLength)
        let status = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, saltLength, bytes.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw PincodeVerifierError.randomUnavailable
        }
        let hash = try derive(pin: pin, salt: salt, iterations: iterations)
        return "\(prefix)\(iterations)$\(salt.base64EncodedString())$\(hash.base64EncodedString())"
    }

    /// The work factors a v1 verifier may state. Outside them the stored value is damaged, not a
    /// PIN to compare (and an absurd factor must not freeze the unlock screen).
    static let acceptedIterations: ClosedRange<UInt32> = 1000 ... 2_000_000

    enum Check: Equatable {
        case match
        case mismatch
        /// The stored value cannot be checked: never the user's mistake, never a counted guess.
        case unreadable
    }

    /// `pin` against `stored`, a verifier or a legacy plain PIN. Constant time in the position of
    /// the first difference. Slow for a verifier: call it off the main thread.
    static func check(_ pin: String, stored: String) -> Check {
        guard isVerifier(stored) else {
            return PincodeComparison.matches(pin, stored) ? .match : .mismatch
        }
        let parts = stored.dropFirst(prefix.count).split(separator: "$", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let iterations = UInt32(parts[0]), acceptedIterations.contains(iterations),
              let salt = Data(base64Encoded: String(parts[1])), salt.count == saltLength,
              let expected = Data(base64Encoded: String(parts[2])), expected.count == outputLength
        else {
            return .unreadable
        }
        guard !pin.isEmpty else {
            return .mismatch
        }
        guard let actual = try? derive(pin: pin, salt: salt, iterations: iterations) else {
            return .unreadable
        }
        var difference: UInt8 = 0
        for index in 0 ..< outputLength {
            difference |= actual[index] ^ expected[index]
        }
        return difference == 0 ? .match : .mismatch
    }

    static func matches(_ pin: String, stored: String) -> Bool {
        check(pin, stored: stored) == .match
    }

    private static func derive(pin: String, salt: Data, iterations: UInt32) throws -> Data {
        let password = Array(pin.utf8)
        var output = [UInt8](repeating: 0, count: outputLength)
        let status = password.withUnsafeBufferPointer { passwordBuffer -> Int32 in
            salt.withUnsafeBytes { saltBytes -> Int32 in
                passwordBuffer.baseAddress!.withMemoryRebound(to: Int8.self, capacity: max(password.count, 1)) { passwordPointer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPointer,
                        password.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress!,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        iterations,
                        &output,
                        output.count
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw PincodeVerifierError.derivationFailed
        }
        return Data(output)
    }
}

enum PincodeVerifierError: Error {
    case randomUnavailable
    case derivationFailed
}
