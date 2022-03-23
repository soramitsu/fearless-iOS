import Foundation
import RobinHood

typealias AppVersionObserverResult = ((Bool?, Error?) -> Void)
typealias AppVersionWireframe = (WarningPresentable & AppUpdatePresentable & PresentDismissable)

protocol AppVersionObserverProtocol {
    func checkVersion(from view: ControllerBackedProtocol?, callback: AppVersionObserverResult?)
}

final class AppVersionObserver {
    private let locale: Locale
    private let wireframe: AppVersionWireframe
    private let currentAppVersion: String?
    private let jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol
    private var displayInfoProvider: AnySingleValueProvider<AppSupportConfig>?

    init(
        jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol,
        currentAppVersion: String?,
        wireframe: AppVersionWireframe,
        locale: Locale
    ) {
        self.jsonLocalSubscriptionFactory = jsonLocalSubscriptionFactory
        self.currentAppVersion = currentAppVersion
        self.wireframe = wireframe
        self.locale = locale
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
    func checkVersion(
        from view: ControllerBackedProtocol?,
        callback: AppVersionObserverResult?
    ) {
        clear(singleValueProvider: &displayInfoProvider)

        guard let url = ApplicationConfig.shared.appVersionURL,
              currentAppVersion != nil else {
            return
        }

        let displayInfoProvider: AnySingleValueProvider<AppSupportConfig> =
            jsonLocalSubscriptionFactory.getJson(for: url)

        let updateClosure: ([DataProviderChange<AppSupportConfig>]) -> Void = { [weak self] changes in
            let result = changes.reduceToLastChange()

            guard let strongSelf = self else {
                return
            }

            let supported = strongSelf.validateVersion(config: result)
            if !supported {
                strongSelf.wireframe.presentWarningAlert(
                    from: view,
                    config: WarningAlertConfig.unsupportedAppVersionConfig(with: strongSelf.locale)
                ) {
                    strongSelf.wireframe.showAppstoreUpdatePage()
                }
            }

            callback?(supported, nil)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            guard let strongSelf = self else {
                return
            }

            strongSelf.wireframe.presentWarningAlert(
                from: view,
                config: WarningAlertConfig.connectionProblemAlertConfig(with: strongSelf.locale)
            ) {
                strongSelf.wireframe.dismiss(view: view)

                strongSelf.checkVersion(from: view, callback: callback)
            }

            callback?(nil, error)
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
