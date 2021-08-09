import Foundation
import SoraFoundation

struct AnalyticsContainerViewFactory {
    static func createView() -> AnalyticsContainerViewProtocol {
        let rewardsModule = AnalyticsRewardsViewFactory.createView()
        let stakeModule = AnalyticsStakeViewFactory.createView()
        let validatorsModule = AnalyticsValidatorsViewFactory.createView()
        let modules = [rewardsModule, stakeModule, validatorsModule].compactMap { $0 }

        let containerModule = AnalyticsContainerViewController(
            embeddedModules: modules,
            localizationManager: LocalizationManager.shared
        )
        return containerModule
    }
}
