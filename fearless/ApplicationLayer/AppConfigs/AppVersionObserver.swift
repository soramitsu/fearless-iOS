import Foundation
import RobinHood

typealias AppVersionObserverResult = ((Bool?, Error?) -> Void)
typealias AppVersionWireframe = (WarningPresentable & AppUpdatePresentable & PresentDismissable)

protocol AppVersionConfigSource {
    var appVersionURL: URL? { get }
}

extension ApplicationConfig: AppVersionConfigSource {}

protocol AppSupportConfigFetching {
    func fetchAppSupportConfig(from url: URL) -> CompoundOperationWrapper<AppSupportConfig?>
}

struct AppSupportConfigFetcher: AppSupportConfigFetching {
    func fetchAppSupportConfig(from url: URL) -> CompoundOperationWrapper<AppSupportConfig?> {
        JsonSingleProviderSource<AppSupportConfig>(url: url).fetchOperation()
    }
}

protocol AppVersionObserverProtocol {
    func checkVersion(from view: ControllerBackedProtocol?, callback: AppVersionObserverResult?)
}

final class AppVersionObserver {
    private let locale: Locale
    private let wireframe: AppVersionWireframe
    private let currentAppVersion: String?
    private let operationManager: OperationManagerProtocol
    private let configSource: AppVersionConfigSource
    private let configFetcher: AppSupportConfigFetching
    private let callbackQueue: DispatchQueue
    private var displayInfoProvider: AnySingleValueProvider<AppSupportConfig>?

    init(
        operationManager: OperationManagerProtocol,
        currentAppVersion: String?,
        wireframe: AppVersionWireframe,
        locale: Locale,
        configSource: AppVersionConfigSource = ApplicationConfig.shared,
        configFetcher: AppSupportConfigFetching = AppSupportConfigFetcher(),
        callbackQueue: DispatchQueue = .main
    ) {
        self.operationManager = operationManager
        self.currentAppVersion = currentAppVersion
        self.wireframe = wireframe
        self.locale = locale
        self.configSource = configSource
        self.configFetcher = configFetcher
        self.callbackQueue = callbackQueue
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

        guard let url = configSource.appVersionURL,
              currentAppVersion != nil else {
            return
        }

        let wrapper = configFetcher.fetchAppSupportConfig(from: url)
        let operation = wrapper.targetOperation
        operation.completionBlock = { [weak self] in
            guard let strongSelf = self, let result = operation.result else {
                return
            }

            switch result {
            case let .success(config):
                strongSelf.callbackQueue.async {
                    let supported = strongSelf.validateVersion(config: config)
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
            case let .failure(error):
                strongSelf.callbackQueue.async {
                    callback?(nil, error)
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
    }

    private func showVersionUnsupportedAlert(from view: ControllerBackedProtocol?) {
        wireframe.presentWarningAlert(
            from: view,
            config: WarningAlertConfig.unsupportedAppVersionConfig(with: locale)
        ) {
            self.wireframe.showAppstoreUpdatePage()
        }
    }

    private func showCheckFailedAlert(from view: ControllerBackedProtocol?, callback: AppVersionObserverResult?) {
        wireframe.presentWarningAlert(
            from: view,
            config: WarningAlertConfig.connectionProblemAlertConfig(with: locale)
        ) {
            self.wireframe.dismiss(view: view)
            self.checkVersion(from: view, callback: callback)
        }
    }
}
