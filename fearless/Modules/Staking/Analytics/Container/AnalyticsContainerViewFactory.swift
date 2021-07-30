import Foundation
import SoraFoundation

struct AnalyticsContainerViewFactory {
    static func createView() -> AnalyticsContainerViewProtocol {
        let rewardsModule = AnalyticsRewardsViewFactory.createView()
        let stakeModule = AnalyticsStakeViewFactory.createView()
        let modules = [rewardsModule, stakeModule].compactMap { $0 }

        let containerModule = AnalyticsContainerViewController(
            embeddedModules: modules,
            localizationManager: LocalizationManager.shared
        )
        return containerModule
    }
}
