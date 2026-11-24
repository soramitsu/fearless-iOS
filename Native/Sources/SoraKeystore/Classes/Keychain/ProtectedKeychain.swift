/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import LocalAuthentication
import Security

public enum ProtectedKeychainError: Error, Equatable {
    case noKeyFound
    case duplicatedItem
    /// The device owner dismissed the system sheet.
    case canceled
    case authenticationFailed
    /// The item needs the device owner and no prompt may be shown now.
    case interactionNotAllowed
    /// The device has no passcode, so a passcode-bound item cannot exist.
    case passcodeNotSet
    case accessControlUnavailable
    case unexpected(OSStatus)
}

/// Lets an app send some `Keychain` identifiers to another store (see `Keychain.itemRouter`).
public protocol KeychainItemRouting: AnyObject {
    /// The store that owns `identifier`, or nil to use the legacy item.
    func routedKeystore(for identifier: String) -> KeystoreProtocol?
}

/// Items the device owner must approve before they can be read: generic-password items created
/// with `SecAccessControlCreateWithFlags(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
/// .userPresence)`, never synchronized. The service name carries the format version.
///
/// Reads take an `LAContext`: an evaluated one reads without a new prompt; one that was not
/// evaluated shows the system sheet with its `localizedReason`. Existence checks and inventory
/// read attributes only and never prompt.
public final class ProtectedKeychain {
    public static let walletSecretService = "jp.co.soramitsu.fearless.wallet-secret.v2"

    public let service: String

    public init(service: String = ProtectedKeychain.walletSecretService) {
        self.service = service
    }

    /// Creates the item. Adding needs no authentication.
    public func add(_ data: Data, for account: String) throws {
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .userPresence,
            &accessError
        ) else {
            accessError?.release()
            throw ProtectedKeychainError.accessControlUnavailable
        }

        var attributes = baseQuery(account)
        attributes[kSecAttrAccessControl as String] = access
        attributes[kSecValueData as String] = data

        try check(SecItemAdd(attributes as CFDictionary, nil))
    }

    public func read(for account: String, context: LAContext) throws -> Data {
        var query = baseQuery(account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context

        var item: CFTypeRef?
        try check(SecItemCopyMatching(query as CFDictionary, &item))
        guard let data = item as? Data else {
            throw ProtectedKeychainError.unexpected(errSecInternalError)
        }
        return data
    }

    /// Replaces the item's bytes; this needs the device owner, like a read.
    public func update(_ data: Data, for account: String, context: LAContext) throws {
        var query = baseQuery(account)
        query[kSecUseAuthenticationContext as String] = context
        let attributes = [kSecValueData as String: data]
        try check(SecItemUpdate(query as CFDictionary, attributes as CFDictionary))
    }

    /// Attributes only: never prompts.
    public func exists(for account: String) throws -> Bool {
        var query = baseQuery(account)
        query[kSecReturnAttributes as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = Self.silentContext()

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess, errSecInteractionNotAllowed:
            return true
        case errSecItemNotFound:
            return false
        default:
            throw Self.error(for: status)
        }
    }

    /// Deleting needs no authentication.
    public func delete(for account: String) throws {
        try check(SecItemDelete(baseQuery(account) as CFDictionary))
    }

    /// Every account of this service, read from attributes only.
    public func allAccounts() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecUseAuthenticationContext as String: Self.silentContext()
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound {
            return []
        }
        try check(status)
        guard let attributes = items as? [[String: Any]] else {
            throw ProtectedKeychainError.unexpected(errSecInternalError)
        }
        return attributes.compactMap { $0[kSecAttrAccount as String] as? String }.sorted()
    }

    public static func error(for status: OSStatus) -> ProtectedKeychainError {
        switch status {
        case errSecItemNotFound:
            return .noKeyFound
        case errSecDuplicateItem:
            return .duplicatedItem
        case errSecUserCanceled:
            return .canceled
        case errSecAuthFailed:
            return .authenticationFailed
        case errSecInteractionNotAllowed:
            return .interactionNotAllowed
        case errSecNotAvailable:
            return .passcodeNotSet
        default:
            return .unexpected(status)
        }
    }

    private func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw Self.error(for: status)
        }
    }

    private static func silentContext() -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }
}
