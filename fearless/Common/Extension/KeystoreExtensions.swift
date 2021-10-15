import Foundation
import SoraKeystore

extension KeystoreProtocol {
    func loadIfKeyExists(_ tag: String) throws -> Data? {
        guard try checkKey(for: tag) else {
            return nil
        }

        return try fetchKey(for: tag)
    }

    @available(*, deprecated, message: "Use saveKey(_ key: Data, with identifier: String) instead")
    func saveSecretKey(_ secretKey: Data, address: String) throws {
        let tag = KeystoreTag.secretKeyTagForAddress(address)

        try saveKey(secretKey, with: tag)
    }

    func fetchSecretKeyForAddress(_ address: String) throws -> Data? {
        let tag = KeystoreTag.secretKeyTagForAddress(address)

        return try loadIfKeyExists(tag)
    }

    func checkSecretKeyForAddress(_ address: String) throws -> Bool {
        let tag = KeystoreTag.secretKeyTagForAddress(address)
        return try checkKey(for: tag)
    }

    @available(*, deprecated, message: "Use saveKey(_ key: Data, with identifier: String) instead")
    func saveEntropy(_ entropy: Data, address: String) throws {
        let tag = KeystoreTag.entropyTagForAddress(address)

        try saveKey(entropy, with: tag)
    }

    func fetchEntropyForAddress(_ address: String) throws -> Data? {
        let tag = KeystoreTag.entropyTagForAddress(address)

        return try loadIfKeyExists(tag)
    }

    func checkEntropyForAddress(_ address: String) throws -> Bool {
        let tag = KeystoreTag.entropyTagForAddress(address)
        return try checkKey(for: tag)
    }

    @available(*, deprecated, message: "Use saveKey(_ key: Data, with identifier: String) instead")
    func saveDeriviation(_ path: String, address: String) throws {
        guard let data = path.data(using: .utf8) else {
            return
        }

        let tag = KeystoreTag.deriviationTagForAddress(address)

        try saveKey(data, with: tag)
    }

    func fetchDeriviationForAddress(_ address: String) throws -> String? {
        let tag = KeystoreTag.deriviationTagForAddress(address)

        guard let data = try loadIfKeyExists(tag) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func checkDeriviationForAddress(_ address: String) throws -> Bool {
        let tag = KeystoreTag.deriviationTagForAddress(address)
        return try checkKey(for: tag)
    }

    @available(*, deprecated, message: "Use saveKey(_ key: Data, with identifier: String) instead")
    func saveSeed(_ data: Data, address: String) throws {
        let tag = KeystoreTag.seedTagForAddress(address)

        try saveKey(data, with: tag)
    }

    func fetchSeedForAddress(_ address: String) throws -> Data? {
        let tag = KeystoreTag.seedTagForAddress(address)

        return try loadIfKeyExists(tag)
    }

    func checkSeedForAddress(_ address: String) throws -> Bool {
        let tag = KeystoreTag.seedTagForAddress(address)
        return try checkKey(for: tag)
    }
}
