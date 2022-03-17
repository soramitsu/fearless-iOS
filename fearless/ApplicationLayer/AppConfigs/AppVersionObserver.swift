import Foundation
import RobinHood

typealias AppVersionObserverResult = ((Bool, Error?) -> Void)

protocol AppVersionObserverProtocol {
    func checkVersion(callback: @escaping AppVersionObserverResult)
}

class AppVersionObserver {
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

    private func isVersionUnsupported(minimalVersion: String) -> Bool {
        currentAppVersion?.versionLowerThan(minimalVersion) ?? false
    }

    private func isVersionExcluded(excludedVersions: [String]) -> Bool {
        excludedVersions.contains(where: { $0 == currentAppVersion })
    }
}

extension AppVersionObserver: AppVersionObserverProtocol {
    func checkVersion(callback: @escaping AppVersionObserverResult) {
        guard let url = ApplicationConfig.shared.appVersionURL,
              let _ = currentAppVersion else {
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

            var currentVersionSupported: Bool = true

            if let minSupportedVersion = result?.minSupportedVersion,
               strongSelf.isVersionUnsupported(minimalVersion: minSupportedVersion) {
                currentVersionSupported = false
            }

            if let excludedVersions = result?.excludedVersions,
               strongSelf.isVersionExcluded(excludedVersions: excludedVersions) {
                currentVersionSupported = false
            }

            callback(currentVersionSupported, nil)
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
