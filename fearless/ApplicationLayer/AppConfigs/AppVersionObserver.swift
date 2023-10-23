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
    private let operationManager: OperationManagerProtocol
    private var displayInfoProvider: AnySingleValueProvider<AppSupportConfig>?

    init(
        operationManager: OperationManagerProtocol,
        currentAppVersion: String?,
        wireframe: AppVersionWireframe,
        locale: Locale
    ) {
        self.operationManager = operationManager
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

        let source = JsonSingleProviderSource<AppSupportConfig>(url: url)

        let operation = source.fetchOperation().targetOperation
        operation.completionBlock = { [weak self] in
            guard let strongSelf = self, let result = operation.result else {
                return
            }

            switch result {
            case let .success(config):
                DispatchQueue.main.async {
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
                DispatchQueue.main.async {
                    callback?(nil, error)
                }
            }
        }

        operationManager.enqueue(operations: [operation] + operation.dependencies, in: .transient)
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
