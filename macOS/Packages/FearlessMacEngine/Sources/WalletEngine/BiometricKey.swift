import CryptoKit
import Foundation
import LocalAuthentication
import Security
import WalletCore

protocol BiometricKeyAccessing: Sendable {
    func availability() -> BiometricsAvailability
    func remove(allowMissingEntitlement: Bool) throws
    func save(_ key: SymmetricKey) throws
    func read(reason: String, context: LAContext) throws -> SymmetricKey
}

enum BiometricItemError: Error { case missingEntitlement }

struct BiometricKey: BiometricKeyAccessing {
    let service: String
    let account: String
    private var query: [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecUseDataProtectionKeychain: true,
         kSecAttrService: service, kSecAttrAccount: account, kSecAttrSynchronizable: false]
    }

    func availability() -> BiometricsAvailability {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error),
              context.biometryType == .touchID
        else { return .unavailable(reason: "Touch ID is unavailable on this Mac.") }
        context.interactionNotAllowed = true
        var attributes = query
        attributes[kSecUseAuthenticationContext] = context
        attributes[kSecReturnAttributes] = true
        switch SecItemCopyMatching(attributes as CFDictionary, nil) {
        case errSecSuccess, errSecInteractionNotAllowed: return .enabled
        case errSecItemNotFound: return .available
        case errSecMissingEntitlement: return .unavailable(
                reason: "This build lacks the protected keychain entitlement."
            )
        default: return .unavailable(reason: "The protected keychain is unavailable.")
        }
    }

    func remove(allowMissingEntitlement: Bool = false) throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound ||
            (allowMissingEntitlement && status == errSecMissingEntitlement)
        else { throw WalletError.biometricsUnavailable }
    }

    func save(_ key: SymmetricKey) throws {
        var error: Unmanaged<CFError>?
        guard let protection = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw WalletError.biometricsUnavailable
        }
        var attributes = query
        attributes[kSecAttrAccessControl] = protection
        attributes[kSecValueData] = key.withUnsafeBytes { Data($0) }
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecMissingEntitlement {
            throw BiometricItemError.missingEntitlement
        }
        guard status == errSecSuccess else { throw WalletError.biometricsUnavailable }
    }

    func read(reason: String, context: LAContext) throws -> SymmetricKey {
        context.localizedReason = reason
        context.localizedFallbackTitle = ""
        var attributes = query
        attributes[kSecUseAuthenticationContext] = context
        attributes[kSecReturnData] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecUserCanceled || status == errSecAuthFailed {
            throw WalletError.biometricsCancelled
        }
        guard status == errSecSuccess, let bytes = result as? Data, bytes.count == 32 else {
            throw WalletError.biometricsUnavailable
        }
        return SymmetricKey(data: bytes)
    }
}
