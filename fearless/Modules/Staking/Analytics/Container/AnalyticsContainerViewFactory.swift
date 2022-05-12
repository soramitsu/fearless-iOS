import Foundation
import SoraFoundation

struct AnalyticsContainerViewMode: OptionSet {
    typealias RawValue = UInt8

    static let none: AnalyticsContainerViewMode = []
    static let includeValidatorsTab = AnalyticsContainerViewMode(rawValue: 1 << 0)
    static let accountIsNominator = AnalyticsContainerViewMode(rawValue: 1 << 1)

    let rawValue: RawValue

    init(rawValue: RawValue) {
        self.rawValue = rawValue
    }
}

enum AnalyticsContainerViewFactory {
    static func createView(
        mode: AnalyticsContainerViewMode,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> AnalyticsContainerViewProtocol {
        let rewardsModule = AnalyticsRewardsViewFactory.createView(
            accountIsNominator: mode.contains(.accountIsNominator),
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        )
        let stakeModule = AnalyticsStakeViewFactory.createView(with: selectedAccount)
        let validatorsModule = mode.contains(.includeValidatorsTab)
            ? AnalyticsValidatorsViewFactory.createView(
                chain: chain,
                asset: asset,
                selectedAccount: selectedAccount
            )
            : nil
        let modules = [rewardsModule, stakeModule, validatorsModule].compactMap { $0 }

        let containerModule = AnalyticsContainerViewController(
            embeddedModules: modules,
            localizationManager: LocalizationManager.shared
        )
        return containerModule
    }
}
