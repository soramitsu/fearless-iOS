/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import Security

@objc(SSFSoraKeystoreKeychain)
public class Keychain: NSObject, KeystoreProtocol {
    public override init() {}

    public func addKey(_ key: Data, with identifier: String) throws {
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

    private func keystoreError(for status: OSStatus) -> KeystoreError? {
        guard status != errSecDuplicateItem else { return KeystoreError.duplicatedItem }
        guard status != errSecItemNotFound else { return KeystoreError.noKeyFound }
        guard status == errSecSuccess else { return KeystoreError.unexpectedFail }

        return nil
    }
}
