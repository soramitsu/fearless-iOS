import Foundation
import SoraFoundation

struct AnalyticsContainerViewFactory {
    static func createView(includeValidators: Bool) -> AnalyticsContainerViewProtocol {
        let rewardsModule = AnalyticsRewardsViewFactory.createView()
        let stakeModule = AnalyticsStakeViewFactory.createView()
        let validatorsModule = includeValidators ? AnalyticsValidatorsViewFactory.createView() : nil
        let modules = [rewardsModule, stakeModule, validatorsModule].compactMap { $0 }

        let containerModule = AnalyticsContainerViewController(
            embeddedModules: modules,
            localizationManager: LocalizationManager.shared
        )
        return containerModule
    }
}
