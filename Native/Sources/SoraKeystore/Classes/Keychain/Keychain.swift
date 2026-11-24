/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import Security

@objc(SSFSoraKeystoreKeychain)
public class Keychain: NSObject, KeystoreProtocol {
    private static let routerLock = NSLock()
    private static var installedRouter: KeychainItemRouting?

    /// When set, every routed `Keychain` sends the identifiers the router claims to the store it
    /// returns (for example wallet secrets that need the device owner). Nil keeps every item
    /// where it always was.
    public static var itemRouter: KeychainItemRouting? {
        get {
            routerLock.lock()
            defer { routerLock.unlock() }
            return installedRouter
        }
        set {
            routerLock.lock()
            installedRouter = newValue
            routerLock.unlock()
        }
    }

    private let isRouted: Bool

    public override init() {
        isRouted = true
    }

    /// `routed: false` always uses the legacy items; the router itself reads them this way.
    public init(routed: Bool) {
        isRouted = routed
    }

    private func routedKeystore(for identifier: String) -> KeystoreProtocol? {
        guard isRouted else {
            return nil
        }
        return Self.itemRouter?.routedKeystore(for: identifier)
    }

    public func addKey(_ key: Data, with identifier: String) throws {
        if let routed = routedKeystore(for: identifier) {
            return try routed.addKey(key, with: identifier)
        }
        guard let applicationTag = identifier.data(using: String.Encoding.utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: key,
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)

        let optionalError = keystoreError(for: status)
        guard optionalError == nil else { throw optionalError! }
    }

    public func updateKey(_ key: Data, with identifier: String) throws {
        if let routed = routedKeystore(for: identifier) {
            return try routed.updateKey(key, with: identifier)
        }
        guard let applicationTag = identifier.data(using: String.Encoding.utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
        ]

        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: key,
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)

        let optionalError = keystoreError(for: status)
        guard optionalError == nil else { throw optionalError! }
    }

    public func fetchKey(for identifier: String) throws -> Data {
        if let routed = routedKeystore(for: identifier) {
            return try routed.fetchKey(for: identifier)
        }
        guard let applicationTag = identifier.data(using: String.Encoding.utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
            kSecReturnData as String: kCFBooleanTrue as Any,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        let optionalError = keystoreError(for: status)
        guard optionalError == nil else { throw optionalError! }

        guard let key = item as? Data else { throw KeystoreError.unexpectedFail }

        return key
    }

    public func checkKey(for identifier: String) throws -> Bool {
        if let routed = routedKeystore(for: identifier) {
            return try routed.checkKey(for: identifier)
        }
        guard let applicationTag = identifier.data(using: String.Encoding.utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
            kSecReturnData as String: kCFBooleanFalse as Any,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)

        let optionalError = keystoreError(for: status)

        if optionalError == KeystoreError.noKeyFound { return false }

        guard optionalError == nil else { throw optionalError! }

        return true
    }

    public func deleteKey(for identifier: String) throws {
        if let routed = routedKeystore(for: identifier) {
            return try routed.deleteKey(for: identifier)
        }
        guard let applicationTag = identifier.data(using: String.Encoding.utf8) else {
            throw KeystoreError.invalidIdentifierFormat
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: applicationTag,
        ]

        let status = SecItemDelete(query as CFDictionary)

        let optionalError = keystoreError(for: status)
        guard optionalError == nil else { throw optionalError! }
    }

    /// The application tag of every legacy key item, read from attributes only (no data).
    public func applicationTags() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound {
            return []
        }
        let optionalError = keystoreError(for: status)
        guard optionalError == nil else { throw optionalError! }
        guard let attributes = items as? [[String: Any]] else { throw KeystoreError.unexpectedFail }

        return attributes.compactMap { item in
            (item[kSecAttrApplicationTag as String] as? Data).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    private func keystoreError(for status: OSStatus) -> KeystoreError? {
        guard status != errSecDuplicateItem else { return KeystoreError.duplicatedItem }
        guard status != errSecItemNotFound else { return KeystoreError.noKeyFound }
        guard status == errSecSuccess else { return KeystoreError.unexpectedFail }

        return nil
    }
}
