import Foundation
import SoraFoundation
import SSFModels

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
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: AnalyticsRewardsFlow
    ) -> AnalyticsContainerViewProtocol {
        let rewardsModule = AnalyticsRewardsViewFactory.createView(
            flow: flow,
            accountIsNominator: mode.contains(.accountIsNominator),
            chainAsset: chainAsset,
            wallet: wallet
        )
        let stakeModule = flow == .relaychain ? AnalyticsStakeViewFactory.createView(
            with: wallet,
            chainAsset: chainAsset
        ) : nil
        let validatorsModule = (mode.contains(.includeValidatorsTab) && flow == .relaychain)
            ? AnalyticsValidatorsViewFactory.createView(
                chain: chainAsset.chain,
                asset: chainAsset.asset,
                selectedAccount: wallet
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
