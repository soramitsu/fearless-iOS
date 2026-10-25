import Darwin
import Foundation
import Security

/// Separate from wallet keys and historical keychain access. Device-local,
/// nonsynchronizing high-water metadata survives app relaunch and upgrade.
final class MutationAuthorizationKeychainStore: MutationAuthorizationHighWaterStoring {
    typealias Read = (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    typealias Update = (CFDictionary, CFDictionary) -> OSStatus
    typealias Add = (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus

    private let query: [String: Any]
    private let read: Read
    private let update: Update
    private let add: Add

    init(
        audience: String,
        read: @escaping Read = SecItemCopyMatching,
        update: @escaping Update = SecItemUpdate,
        add: @escaping Add = SecItemAdd
    ) throws {
        guard MutationAuthorizationVerifier.matches(audience, "[A-Za-z0-9.-]{1,128}") else {
            throw MutationAuthorizationError.wrongRelease
        }
        query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "io.fearlesswallet.mutation-authorization.v1",
            kSecAttrAccount as String: audience,
            kSecAttrSynchronizable as String: false
        ]
        self.read = read
        self.update = update
        self.add = add
    }

    func load() throws -> MutationAuthorizationHighWater? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var value: CFTypeRef?
        let status = read(lookup as CFDictionary, &value)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = value as? Data, data.count <= 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(["revision", "payloadSha256", "maximumWallSeconds"]),
              let record = try? JSONDecoder().decode(MutationAuthorizationHighWater.self, from: data),
              record.isValid else {
            throw MutationAuthorizationError.persistenceUnavailable
        }
        return record
    }

    func save(_ value: MutationAuthorizationHighWater) throws {
        guard value.isValid else { throw MutationAuthorizationError.persistenceUnavailable }
        // Defend accidental stale writers too. The authority remains the sole
        // writer; Keychain has no compare-and-swap operation across processes.
        if let previous = try load() {
            guard value.revision >= previous.revision,
                  value.maximumWallSeconds >= previous.maximumWallSeconds,
                  value.revision != previous.revision || value.payloadSha256 == previous.payloadSha256 else {
                throw MutationAuthorizationError.rollback
            }
        }
        let attributes: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(value),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = update(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = add(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw MutationAuthorizationError.persistenceUnavailable }
    }
}

extension MutationAuthorizationClock {
    static func system() -> MutationAuthorizationClock {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        // Convert before multiplication so the raw UInt64 counter cannot wrap.
        let seconds = Double(mach_continuous_time()) * Double(timebase.numer) /
            Double(timebase.denom) / 1_000_000_000
        return MutationAuthorizationClock(
            wallSeconds: Int64(Date().timeIntervalSince1970), continuousSeconds: seconds
        )
    }
}
