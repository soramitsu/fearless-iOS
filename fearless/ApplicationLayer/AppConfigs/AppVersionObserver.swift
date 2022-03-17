import Foundation
import RobinHood

protocol AppVersionObserverDelegate: AnyObject {
    func handleAppVersionUnsupported()
}

protocol AppVersionObserverProtocol {
    func checkVersion(_ version: String)
}

class AppVersionObserver {
    weak var delegate: AppVersionObserverDelegate?
    private var currentAppVersion: String
    private var jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol

    init(jsonLocalSubscriptionFactory: JsonDataProviderFactoryProtocol,
         currentAppVersion: String) {
        self.jsonLocalSubscriptionFactory = jsonLocalSubscriptionFactory
        self.currentAppVersion = currentAppVersion
    }

    func checkVersion(_ version: String) {
        guard let url = ApplicationConfig.shared.appVersionURL else {
            return
        }

        let displayInfoProvider: AnySingleValueProvider<AppSupportConfig> =
            jsonLocalSubscriptionFactory.getJson(for: url)

        let updateClosure: ([DataProviderChange<AppSupportConfig>]) -> Void = { [weak self] changes in
            let result = changes.reduceToLastChange()
    
            guard let strongSelf = self,
                    let minSupportedVersion = result?.minSupportedVersion else {
                return
            }
            
            if strongSelf.currentVersionLowerThan(version: minSupportedVersion) {
                strongSelf.delegate?.handleAppVersionUnsupported()
            }
        }

        let failureClosure: (Error) -> Void = { _ in }

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
    }
    
    private func currentVersionLowerThan(version: String) -> Bool {
        let comparator = AppVersionComparator()
        return comparator.isCurrentVersionLowerThanMinimal(currentVersion: currentAppVersion,
                                                           minimalVersion: version)
    }
}
