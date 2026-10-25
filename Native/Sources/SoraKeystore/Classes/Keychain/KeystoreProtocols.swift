/**
 * Copyright Soramitsu Co., Ltd. All Rights Reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public enum KeystoreError: Error {
    case invalidIdentifierFormat
    case noKeyFound
    case duplicatedItem
    case unexpectedFail
}

public protocol KeystoreProtocol: AnyObject {
    func addKey(_ key: Data, with identifier: String) throws
    func updateKey(_ key: Data, with identifier: String) throws
    func fetchKey(for identifier: String) throws -> Data
    func checkKey(for identifier: String) throws -> Bool
    func deleteKey(for identifier: String) throws
}

public extension KeystoreProtocol {
    func saveKey(_ key: Data, with identifier: String) throws {
        let exists = try checkKey(for: identifier)
        if !exists {
            try addKey(key, with: identifier)
        } else {
            try updateKey(key, with: identifier)
        }
    }

    func deleteKeyIfExists(for identifier: String) throws {
        let exists = try checkKey(for: identifier)
        if exists {
            try deleteKey(for: identifier)
        }
    }

    func deleteKeysIfExist(for identifiers: [String]) throws {
        for identifier in identifiers {
            try deleteKeyIfExists(for: identifier)
        }
    }
}

public protocol SecretDataRepresentable {
    func asSecretData() -> Data?
}

public extension SecretDataRepresentable {
    func toUTF8String() -> String? {
        guard let existingData = asSecretData() else { return nil }
        return String(data: existingData, encoding: .utf8)
    }
}

extension String: SecretDataRepresentable {
    public func asSecretData() -> Data? {
        data(using: .utf8)
    }
}

extension Data: SecretDataRepresentable {
    public func asSecretData() -> Data? {
        self
    }
}

public protocol SecretStoreManagerProtocol: AnyObject {
    func loadSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (SecretDataRepresentable?) -> Void
    )

    func saveSecret(
        _ secret: SecretDataRepresentable,
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    )

    func removeSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    )

    func checkSecret(
        for identifier: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    )

    func checkSecret(for identifier: String) -> Bool
}
