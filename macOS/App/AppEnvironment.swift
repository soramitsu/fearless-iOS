import Foundation
import WalletEngine

/// Launch-time configuration of the engine.
enum AppEnvironment {
    /// Debug builds accept `FEARLESS_STORAGE_PROFILE=<name>` so UI tests and
    /// manual checks run against a throwaway wallet store next to the real
    /// one (`…/Application Support/Fearless-<name>`, inside the sandbox
    /// container) with its own keychain items. Release builds always use the
    /// default store.
    static func engineConfiguration(environment: [String: String] = ProcessInfo.processInfo.environment) -> WalletEngineConfiguration {
        var configuration = WalletEngineConfiguration.default
        #if DEBUG
        if let profile = sanitizedProfile(environment["FEARLESS_STORAGE_PROFILE"]) {
            configuration.storageDirectory = configuration.storageDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("Fearless-\(profile)", isDirectory: true)
            configuration.keychainService += ".profile.\(profile)"
        }
        #endif
        return configuration
    }

    /// Letters, digits, `-` and `_` only, at most 64 characters.
    static func sanitizedProfile(_ value: String?) -> String? {
        guard let value, !value.isEmpty, value.count <= 64,
              value.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) && $0.isASCII || $0 == "-" || $0 == "_" })
        else { return nil }
        return value
    }
}
