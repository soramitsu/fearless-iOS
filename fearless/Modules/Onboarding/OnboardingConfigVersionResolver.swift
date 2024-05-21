final class OnboardingConfigVersionResolver {
    func resolve(configWrappers: [OnboardingConfigWrapper]) -> OnboardingConfigWrapper? {
        var versionsForConfigs: [String: OnboardingConfigWrapper] = [:]
        configWrappers.forEach { versionsForConfigs[$0.minVersion] = $0 }
        guard let currentAppVersion = AppVersion.stringValue else {
            return nil
        }
        if versionsForConfigs.keys.contains(currentAppVersion) {
            return versionsForConfigs[currentAppVersion]
        } else {
            let availableVersions = versionsForConfigs.keys
                .filter { $0.versionLowerThan(currentAppVersion) }
                .sorted { $0.versionLowerThan($1) }
            guard let lastAvailableVersion = availableVersions.last else {
                return nil
            }
            return versionsForConfigs[lastAvailableVersion]
        }
    }
}
