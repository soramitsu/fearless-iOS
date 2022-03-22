import Foundation
import RobinHood

typealias AppVersionObserverResult = ((Bool, Error?) -> Void)

protocol AppVersionObserverProtocol {
    func checkVersion(callback: @escaping AppVersionObserverResult)
}

final class AppVersionObserver {
    private var currentAppVersion: String?
    private var jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol
    var displayInfoProvider: AnySingleValueProvider<AppSupportConfig>?

    init(
        jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol,
        currentAppVersion: String?
    ) {
        self.jsonLocalSubscriptionFactory = jsonLocalSubscriptionFactory
        self.currentAppVersion = currentAppVersion
    }

    private func validateVersion(config: AppSupportConfig?) -> Bool {
        !checkVersionExcluded(excludedVersions: config?.excludedVersions)
            && !checkVersionUnsupported(minimalVersion: config?.minSupportedVersion)
    }

    private func checkVersionUnsupported(minimalVersion: String?) -> Bool {
        guard let minimalVersion = minimalVersion else {
            return false
        }

        return currentAppVersion?.versionLowerThan(minimalVersion) ?? false
    }

    private func checkVersionExcluded(excludedVersions: [String]?) -> Bool {
        guard let excludedVersions = excludedVersions else {
            return false
        }

        return excludedVersions.contains(where: { $0 == currentAppVersion })
    }
}

extension AppVersionObserver: AnyProviderAutoCleaning {}

extension AppVersionObserver: AppVersionObserverProtocol {
    func checkVersion(callback: @escaping AppVersionObserverResult) {
        clear(singleValueProvider: &displayInfoProvider)

        guard let url = ApplicationConfig.shared.appVersionURL,
              currentAppVersion != nil else {
            callback(true, nil)
            return
        }

        let displayInfoProvider: AnySingleValueProvider<AppSupportConfig> =
            jsonLocalSubscriptionFactory.getJson(for: url)

        let updateClosure: ([DataProviderChange<AppSupportConfig>]) -> Void = { [weak self] changes in
            let result = changes.reduceToLastChange()

            guard let strongSelf = self else {
                return
            }

            callback(strongSelf.validateVersion(config: result), nil)
        }

        let failureClosure: (Error) -> Void = { error in
            callback(true, error)
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        displayInfoProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        self.displayInfoProvider = displayInfoProvider
    }
}
