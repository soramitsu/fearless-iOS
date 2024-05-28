import SoraKeystore

enum OnboardingKeys: String {
    case lastShownOnboardingVersion
}

final class OnboardingConfigVersionResolver {
    private let userDefaultsStorage: SettingsManagerProtocol

    init(userDefaultsStorage: SettingsManagerProtocol) {
        self.userDefaultsStorage = userDefaultsStorage
    }

    func resolve(configWrappers: [OnboardingConfigWrapper]) -> OnboardingConfigWrapper? {
        guard let currentAppVersion = AppVersion.stringValue else {
            return nil
        }

        var versionsForConfigs: [String: OnboardingConfigWrapper] = [:]
        configWrappers.forEach { versionsForConfigs[$0.minVersion] = $0 }

        var availableVersion: String

        if versionsForConfigs.keys.contains(currentAppVersion) {
            availableVersion = currentAppVersion
        } else {
            let availableVersions = versionsForConfigs.keys
                .filter { $0.versionLowerThan(currentAppVersion) }
                .sorted { $0.versionLowerThan($1) }
            guard let lastAvailableVersion = availableVersions.first else {
                return nil
            }
            availableVersion = lastAvailableVersion
        }

        if let lastShownVersion = userDefaultsStorage.string(for: OnboardingKeys.lastShownOnboardingVersion.rawValue) {
            return lastShownVersion.versionLowerThan(availableVersion) ? versionsForConfigs[availableVersion] : nil
        } else {
            return versionsForConfigs[availableVersion]
        }
    }
}
